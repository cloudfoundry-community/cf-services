# Copyright (c) 2009-2011 VMware, Inc.

require 'fileutils'
require 'redis'
require 'base64'

require 'postgresql_service/common'
require 'postgresql_service/job'

class VCAP::Services::Postgresql::Provisioner < VCAP::Services::Base::Provisioner
  include VCAP::Services::Postgresql::Common

  def create_snapshot_job
    VCAP::Services::Postgresql::Snapshot::CreateSnapshotJob
  end

  def rollback_snapshot_job
    VCAP::Services::Postgresql::Snapshot::RollbackSnapshotJob
  end

  def delete_snapshot_job
    VCAP::Services::Base::AsyncJob::Snapshot::BaseDeleteSnapshotJob
  end

  def create_serialized_url_job
    VCAP::Services::Base::AsyncJob::Serialization::BaseCreateSerializedURLJob
  end

  def import_from_url_job
    VCAP::Services::Postgresql::Serialization::ImportFromURLJob
  end

  def ioctl(id, payload, &blk)
    @logger.debug("[#{service_description}] Processing ioctl '#{payload}' for #{id}")
    begin
      svc = get_instance_handle(id)
      raise ServiceError.new(ServiceError::NOT_FOUND, id) if svc.nil?
      node_id = svc[:credentials]["node_id"]
      raise "Cannot find node_id for #{id}" if node_id.nil?
      request = {id: id, payload: Yajl::Parser.parse(payload)}.to_json
      subscription = nil
      timer = EM.add_timer(@node_timeout) {
        @node_nats.unsubscribe(subscription)
        blk.call(timeout_fail)
      }
      subscription = @node_nats.request("#{service_name}.ioctl.#{node_id}", request) do |msg|
        EM.cancel_timer(timer)
        @node_nats.unsubscribe(subscription)
        @logger.debug("[#{service_description}] Ioctl response: #{msg}")
        blk.call(success(msg))
      end
    rescue => e
      if e.instance_of? ServiceError
        blk.call(failure(e))
      else
        @logger.warn("Internal error while processing ioctl: #{e}")
        blk.call(internal_fail)
      end
    end
  end
  
end
