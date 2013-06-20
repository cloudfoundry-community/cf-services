cf-services
====

This repo is an attempt to stabilize Cloud Foundry data services
(MySQL, MongoDB, etc).  The service code in the
cloudfoundry/{cf-release, vcap-services, cf-services-contrib,
cf-services-release} is dysfunctional in various ways.

Note that this repo contains both [source](src) and the corresponding
[Bosh jobs and packages](release).

Note that other CF components must also be fixed.  Specifically, you
must use the ["fix_services" branch of
cloudfoundry-community/cloud_controller_ng](https://github.com/cloudfoundry-community/cloud_controller_ng/tree/fix_services)
rather than the [stock
cloudfoundry/cloud_controller_ng](https://github.com/cloudfoundry/cloud_controller_ng)
-- hopefully this will be resolved soon.
