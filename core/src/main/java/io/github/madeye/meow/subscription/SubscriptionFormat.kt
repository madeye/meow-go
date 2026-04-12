package io.github.madeye.meow.subscription

/**
 * Pure-Kotlin heuristic that decides whether a subscription body is already
 * a clash YAML document (store verbatim) or a v2rayN-style nodelist that
 * needs to be converted through mihomo's `common/convert` package.
 *
 * Deliberately *not* a parser — we only peek at the first 512 characters
 * looking for unambiguous clash keys. A body that passes this check is
 * still validated later by mihomo's real YAML parser.
 */
object SubscriptionFormat {
    private const val SCAN = 512
    private val CLASH_KEYS = arrayOf(
        "proxies:",
        "proxy-groups:",
        "mixed-port:",
        "port:",
        "mode:",
    )

    fun isClashYaml(raw: ByteArray): Boolean {
        if (raw.isEmpty()) return false
        var offset = 0
        // Strip UTF-8 BOM.
        if (raw.size >= 3 &&
            raw[0] == 0xEF.toByte() &&
            raw[1] == 0xBB.toByte() &&
            raw[2] == 0xBF.toByte()
        ) {
            offset = 3
        }
        val head = String(
            raw,
            offset,
            minOf(SCAN, raw.size - offset),
            Charsets.UTF_8,
        )
        // Look for any clash key at column 0 of a line (optionally
        // preceded by a BOM-less empty line).
        val lines = head.lineSequence()
        for (line in lines) {
            for (key in CLASH_KEYS) {
                if (line.startsWith(key)) return true
            }
        }
        return false
    }
}
