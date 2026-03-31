package io.github.madeye.meow.aidl

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class TrafficStats(
    var txRate: Long = 0L,
    var rxRate: Long = 0L,
    var txTotal: Long = 0L,
    var rxTotal: Long = 0L,
) : Parcelable {
    operator fun plus(other: TrafficStats) = TrafficStats(
        txRate + other.txRate,
        rxRate + other.rxRate,
        txTotal + other.txTotal,
        rxTotal + other.rxTotal,
    )
}
