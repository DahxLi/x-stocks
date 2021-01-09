# frozen_string_literal: true

module API
  module Entities
    class Exchange < API::Entities::Base
      expose :name
      expose :code
      expose :region
    end
  end
end
