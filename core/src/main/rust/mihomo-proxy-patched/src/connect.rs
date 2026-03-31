//! Protected TCP connect — routes through a global pre-connect hook.
//!
//! On Android, set_pre_connect_hook() is called at startup to register
//! a callback that invokes VpnService.protect(fd) before connect().
//! On other platforms, the hook is None and we fall back to TcpStream::connect().

use std::net::SocketAddr;
use std::os::unix::io::AsRawFd;
use std::sync::OnceLock;
use tokio::net::TcpStream;

/// A callback invoked with the raw fd before connect(). Returns true if protected.
type ProtectHook = Box<dyn Fn(i32) -> bool + Send + Sync>;

static PROTECT_HOOK: OnceLock<ProtectHook> = OnceLock::new();

/// Register a global pre-connect hook. Call once at startup.
pub fn set_pre_connect_hook(hook: impl Fn(i32) -> bool + Send + Sync + 'static) {
    PROTECT_HOOK.set(Box::new(hook)).ok();
}

/// Connect a TCP stream, calling the protect hook before connect() if set.
pub async fn protected_tcp_connect(addr: &str) -> std::io::Result<TcpStream> {
    // If no hook is set, just use regular connect
    let hook = match PROTECT_HOOK.get() {
        Some(h) => h,
        None => return TcpStream::connect(addr).await,
    };

    // Resolve address
    let sock_addr: SocketAddr = match addr.parse() {
        Ok(a) => a,
        Err(_) => {
            let addrs: Vec<SocketAddr> = tokio::net::lookup_host(addr).await?.collect();
            *addrs.first().ok_or_else(|| {
                std::io::Error::new(std::io::ErrorKind::AddrNotAvailable, "no addresses found")
            })?
        }
    };

    let domain = match sock_addr {
        SocketAddr::V4(_) => socket2::Domain::IPV4,
        SocketAddr::V6(_) => socket2::Domain::IPV6,
    };

    let socket = socket2::Socket::new(domain, socket2::Type::STREAM, Some(socket2::Protocol::TCP))?;
    socket.set_nonblocking(true)?;

    // Protect BEFORE connect
    (hook)(socket.as_raw_fd());

    // Start non-blocking connect
    let sock_addr2 = socket2::SockAddr::from(sock_addr);
    match socket.connect(&sock_addr2) {
        Ok(()) => {}
        Err(e) if e.raw_os_error() == Some(libc::EINPROGRESS) => {}
        Err(e) => return Err(e),
    }

    let std_stream: std::net::TcpStream = socket.into();
    let stream = TcpStream::from_std(std_stream)?;

    // Wait for connect to complete
    stream.writable().await?;
    if let Some(err) = stream.take_error()? {
        return Err(err);
    }

    Ok(stream)
}
