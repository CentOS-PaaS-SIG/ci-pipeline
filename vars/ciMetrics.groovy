import org.centos.pipeline.CIMetrics

/*
A class to store build metrics over the lifetime of the build.
Metrics are stored in customDataMap and then sent to influx at
the end of the job. Example usage:

try {
    def stepName = "mystep"
    ciMetrics.timed stepName, {
        stage(stepName) {
            echo "in mystep"
        }
    }
    currentBuild.result = "SUCCESS"
} catch(err) {
    currentBuild.result = "FAILED"
    throw err
} finally {
    ciMetrics.writeToInflux()
}
 */
class ciMetrics {

    // A map to store the data sent to influx
    def customDataMap = [:]
    // Global tags
    def customDataMapTags = [:]
    // This will prefix the data sent to influx. Usually set to the job name.
    def prefix = "ci_pipeline"
    // The influx target configured in jenkins
    def influxTarget = "localInflux"

    def cimetrics = new CIMetrics()

    /**
     * Call this method to record the step run time
     * @param name - the step name
     * @param body - the enclosing step body
     */
    def timed(String measurement, String name, Closure body) {
        setMetricField(measurement, name, cimetrics.timed(body))

    }

    def setMetricField(String measurement, String key, def value) {
        if (!customDataMap[measurement]) {
            customDataMap[measurement] = [:]
        }

        customDataMap[measurement][key] = value
    }

    def setMetricTag(String measurement, String key, String value) {
        if (!customDataMapTags[measurement]) {
            customDataMapTags[measurement] = [:]
        }

        customDataMapTags[measurement][key] = value
    }

    /**
     * Write customDataMap to influxDB
     */
    def writeToInflux() {
        cimetrics.writeToInflux(influxTarget, prefix, customDataMap, customDataMapTags)
    }
}