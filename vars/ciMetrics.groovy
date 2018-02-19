import org.centos.pipeline.CIMetrics


class ciMetrics {

    def customDataMap = ["ci_pipeline": [:]]
    def prefix = "ci_pipeline"
    def influxTarget = "localInflux"
    def measurement = "ci_pipeline"
    def cimetrics = new CIMetrics()

    /**
     * Call this method to record the step run time
     * @param name - the step name
     * @param body - the enclosing step body
     */
    def timed(String name, Closure body) {
		customDataMap[measurement][name] = cimetrics.timed(body)

    }

    /**
     *
     * @param name
     * @param value
     */
    def setTagField(String name, def value) {
        customDataMap[measurement][name] = value
    }

    /**
     * Write customDataMap to influxDB
     */
    def writeToInflux() {
        cimetrics.writeToInflux(influxTarget, prefix, customDataMap)
    }
}
