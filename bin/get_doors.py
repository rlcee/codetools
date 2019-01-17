#! /bin/env python
import json
import urllib2

url = "http://fndca.fnal.gov:2288/info/doors?format=json"

request = urllib2.Request(url)
request.add_header("Accept","application/json")
response = urllib2.urlopen(request)
data = json.load(response)


for name, value in data.iteritems():
    protocol = value.get("protocol")
    family = protocol.get("family")
    if family != "root" : continue
    port = value.get("port")
    host = value.get("interfaces").values()[0].get("FQDN")
    """
    skip r/o doors
    """
    if port == 1095 : continue
    print "root://{0}:{1}".format(host, port)

