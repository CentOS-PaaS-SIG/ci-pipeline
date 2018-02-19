package org.centos.pipeline

/**
 *
 * @param influxTarget - the configured influx instance
 * @param prefix - any name to prefix the data
 * @param customDataMap - the data to be written to influx
 */
def writeToInflux(String influxTarget, String prefix, Map customDataMap) {
    step([$class: 'InfluxDbPublisher',
          customData: [:],
          customDataMap: customDataMap,
          customPrefix: prefix,
          target: influxTarget])

}

/**
 *
 * @param name
 * @param body
 * @return the duration of the step
 */
def timed(Closure body) {
    def start = System.currentTimeMillis()

    body()

    def now = System.currentTimeMillis()

    return now - start

}
