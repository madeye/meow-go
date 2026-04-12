package io.github.madeye.meow.subscription

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionFormatTest {

    private val clashYaml = """
        mixed-port: 7890
        mode: rule
        proxies:
          - name: demo
            type: ss
            server: 1.2.3.4
            port: 8388
            cipher: aes-256-gcm
            password: pw
        proxy-groups:
          - name: Proxy
            type: select
            proxies: [demo]
        rules:
          - MATCH,Proxy
    """.trimIndent()

    private val base64Nodelist =
        "c3M6Ly9ZV1Z6TFRJMU5pMW5ZMjA2ZEdWemRIQmhjM04zYjNKa01USXpAMTI3LjAuMC4xOjgzODgjdGVzdC1ub2RlLTEKc3M6Ly9ZV1Z6TFRJMU5pMW5ZMjA2ZEdWemRIQmhjM04zYjNKa01USXpAMTI3LjAuMC4xOjgzODgjdGVzdC1ub2RlLTIK"

    private val plainNodelist = """
        vless://abc@1.2.3.4:443?type=ws#foo
        ss://YWVzLTI1Ni1nY206cHc=@1.2.3.4:8388#bar
    """.trimIndent()

    private val garbage = "<!DOCTYPE html><html><body>Not Found</body></html>"

    @Test
    fun `clash yaml is recognised`() {
        assertTrue(SubscriptionFormat.isClashYaml(clashYaml.toByteArray()))
    }

    @Test
    fun `base64 nodelist is not clash yaml`() {
        assertFalse(SubscriptionFormat.isClashYaml(base64Nodelist.toByteArray()))
    }

    @Test
    fun `plain uri nodelist is not clash yaml`() {
        assertFalse(SubscriptionFormat.isClashYaml(plainNodelist.toByteArray()))
    }

    @Test
    fun `garbage is not clash yaml`() {
        assertFalse(SubscriptionFormat.isClashYaml(garbage.toByteArray()))
    }

    @Test
    fun `leading BOM plus yaml is recognised`() {
        val bom = byteArrayOf(0xEF.toByte(), 0xBB.toByte(), 0xBF.toByte())
        assertTrue(SubscriptionFormat.isClashYaml(bom + clashYaml.toByteArray()))
    }
}
