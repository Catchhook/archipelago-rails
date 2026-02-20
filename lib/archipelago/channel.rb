# frozen_string_literal: true

base_channel = if defined?(::ApplicationCable::Channel)
  ::ApplicationCable::Channel
elsif defined?(ActionCable::Channel::Base)
  ActionCable::Channel::Base
else
  Class.new do
    def stream_from(*); end
    def reject; end
    def params = {}
  end
end

channel_class = Class.new(base_channel) do
  def subscribed
    stream_name = verified_stream_name
    reject unless stream_name

    stream_from(stream_name)
  end

  private

  def verified_stream_name
    stream_name = params[:stream_name].to_s
    return nil unless stream_name.match?(self.class::STREAM_PATTERN)

    stream_name
  end
end

channel_class.const_set(:STREAM_PATTERN, /\A[A-Za-z0-9:_-]+\z/)

Archipelago.send(:remove_const, :IslandChannel) if Archipelago.const_defined?(:IslandChannel, false)
Archipelago.const_set(:IslandChannel, channel_class)
