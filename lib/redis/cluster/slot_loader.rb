# frozen_string_literal: true

require_relative '../errors'
require_relative 'node_key'

class Redis
  class Cluster
    # Load and hashify slot info for Redis Cluster Client
    module SlotLoader
      module_function

      def load(nodes)
        info = {}

        nodes.each do |node|
          info = fetch_slot_info(node)
          info.empty? ? next : break
        end

        return info unless info.empty?

        raise CannotConnectError, 'Redis client could not connect to any cluster nodes'
      end

      def fetch_slot_info(node)
        hash_with_default_arr = Hash.new { |h, k| h[k] = [] }
        node.call(%i[cluster slots])
            .flat_map { |arr| parse_slot_info(arr, default_ip: node.host) }
            .each_with_object(hash_with_default_arr) { |arr, h| h[arr[0]] << arr[1] }
      rescue CannotConnectError, ConnectionError, CommandError
        {} # can retry on another node
      end

      def parse_slot_info(arr, default_ip:)
        first_slot, last_slot = arr[0..1]
        slot_range = (first_slot..last_slot).freeze
        arr[2..-1].map { |addr| [stringify_node_key(addr, default_ip), slot_range] }
      end

      def stringify_node_key(arr, default_ip)
        ip, port = arr
        ip = default_ip if ip.empty? # When cluster is down
        NodeKey.build_from_host_port(ip, port)
      end

      private_class_method :fetch_slot_info, :parse_slot_info, :stringify_node_key
    end
  end
end
