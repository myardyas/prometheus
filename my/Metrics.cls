Class my.Metrics Extends %CSP.REST
{

Parameter ISCPREFIX = "isc_cache";

Parameter DASHPREFIX = {..#ISCPREFIX_"_dashboard"};

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/cache" Method="GET" Call="getMetrics"/>
</Routes>
}

/// Output should obey the Prometheus exposition formats. Docs:
/// https://prometheus.io/docs/instrumenting/exposition_formats/
/// 
/// The protocol is line-oriented. A line-feed character (\n) separates lines. 
/// The last line must end with a line-feed character. Empty lines are ignored.
ClassMethod getMetrics() As %Status
{
	set nl = $c(10)
	do ..getDashboardSample(.dashboard)
	do ..getClassProperties(dashboard.%ClassName(1), .propList, .descrList)
	
	for i=1:1:$ll(propList) {
		set descr = $lg(descrList,i)
		set propertyName = $lg(propList,i)
		set propertyValue = $property(dashboard, propertyName)
		
		// Prometheus supports time series database 
		// so if we get empty (for example, backup metrics) or non-digital metrics 
		// we just omit them.
		if ((propertyValue '= "") && ('$match(propertyValue, ".*[-A-Za-z ]+.*"))) {
			set metricsName = ..#DASHPREFIX_..camelCase2Underscore(propertyName)
			set metricsValue = propertyValue
			
			// Write description (help) for each metrics.
			// Format is that the Prometheus requires.
			// Multiline descriptions we have to join in one string.
			write "# HELP "_metricsName_" "_$replace(descr,nl," ")_nl
			write metricsName_" "_metricsValue_nl
		}
	}
	
	write nl
	quit $$$OK
}

ClassMethod getDashboardSample(Output dashboard)
{
	new $namespace
	set $namespace = "%SYS"
	set dashboard = ##class(SYS.Stats.Dashboard).Sample()
}

ClassMethod getClassProperties(className As %String, Output propList As %List, Output descrList As %List)
{
	new $namespace
	set $namespace = "%SYS"
	
	set propList = "", descrList = ""
	set properties = ##class(%Dictionary.ClassDefinition).%OpenId(className).Properties
	
	for i=1:1:properties.Count() {
		set property = properties.GetAt(i)
		set propList = propList_$lb(property.Name)
		set descrList = descrList_$lb(property.Description)
	}
}

/// Converts metrics name in camel case to underscore name with lower case
/// Sample: input = WriteDaemon, output = _write_daemon
ClassMethod camelCase2Underscore(metrics As %String) As %String
{
	set result = metrics
	set regexp = "([A-Z])"
	set matcher = ##class(%Regex.Matcher).%New(regexp, metrics)
	while (matcher.Locate()) {
		set result = matcher.ReplaceAll("_"_"$1")
	}
	
	// To lower case
	set result = $zcvt(result, "l")
	
	// _e_c_p (_c_s_p) to _ecp (_csp)
	set result = $replace(result, "_e_c_p", "_ecp")
	set result = $replace(result, "_c_s_p", "_csp")
	
	quit result
}

}

