# frozen_string_literal: true

module PlatformosCheck
  module Tags
    class Log < Base
      class ParseTreeVisitor < Liquid::ParseTreeVisitor
        def children
          [
            @node.value_expr
          ].compact + @node.attributes_expr.values
        end
      end
    end
  end
end
