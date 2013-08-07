# Copyright (c) 2009-2011 VMware, Inc.
require 'fileutils'
require 'redis'
require 'base64'

$LOAD_PATH.unshift File.join(File.dirname __FILE__)
require 'common'
require 'job'

class VCAP::Services::Mysql::Provisioner < VCAP::Services::Base::Provisioner
  include VCAP::Services::Mysql::Common

  def create_snapshot_job
    VCAP::Services::Mysql::Snapshot::CreateSnapshotJob
  end

  def rollback_snapshot_job
    VCAP::Services::Mysql::Snapshot::RollbackSnapshotJob
  end

  def delete_snapshot_job
    VCAP::Services::Base::AsyncJob::Snapshot::BaseDeleteSnapshotJob
  end

  def create_serialized_url_job
    VCAP::Services::Base::AsyncJob::Serialization::BaseCreateSerializedURLJob
  end

  def import_from_url_job
    VCAP::Services::Mysql::Serialization::ImportFromURLJob
  end

  def varz_details
    varz = super

    @plan_mgmt.each do |plan, v|
      plan_nodes = @nodes.select { |_, node| node["plan"] == plan.to_s }.values
      if plan_nodes.size > 0
        available_capacity, max_capacity, used_capacity = compute_availability(plan_nodes)
        varz.fetch(:plans).each do |plan_detail|
          if (plan_detail.fetch(:plan) == plan)
            plan_detail.merge!({available_capacity: available_capacity})
            plan_detail.merge!({max_capacity: max_capacity})
            plan_detail.merge!({used_capacity: used_capacity})
          end
        end
      end
    end
    varz
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

  private

  def compute_availability(plan_nodes)
    max_capacity = plan_nodes.inject(0) { |sum, node| sum + node.fetch('max_capacity', 0) }
    available_capacity = plan_nodes.inject(0) { |sum, node| sum + node.fetch('available_capacity', 0) }
    used_capacity = max_capacity - available_capacity
    return available_capacity, max_capacity, used_capacity
  end

end
