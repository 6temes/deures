module Ops
  module Children
    class Create < Ops::Base
      operation name: "children.create",
        description: "Create a child with a name and a color from the Home Screen palette.",
        example: %(Ops::Children::Create.call name: "Mar", color: "pink")

      def initialize(name:, color:)
        @name, @color = name, color
      end

      def perform
        refuse! %(no color called "#{@color}" — the icons are: #{Child::COLORS.keys.join(", ")}) unless Child::COLORS.key?(@color)
        refuse! %(there is already a child called "#{@name}", and every operation names a child by name) if Child.exists?(name: @name)

        before = Child.count
        child = Child.create! color: @color, created_on: Date.current, name: @name

        "children #{before} → #{Child.count}: #{child.name} in #{child.color}, " \
          "threshold #{child.light_day_threshold}, cap #{child.new_card_cap}"
      end
    end

    class SetPace < Ops::Base
      include Lookups

      operation name: "children.set_pace",
        description: "Set a child's light-day threshold and the daily cap on new cards.",
        example: %(Ops::Children::SetPace.call child: "Teo", threshold: 12, cap: 3)

      def initialize(child:, cap: nil, threshold: nil)
        @name, @cap, @threshold = child, cap, threshold
      end

      def perform
        child = child! @name
        threshold = @threshold || child.light_day_threshold
        cap = @cap || child.new_card_cap

        refuse! "a threshold of #{threshold} would leave no room for a new card — pass 1 or more" if threshold < 1
        refuse! "a cap of #{cap} is not a number of cards — pass 0 or more" if cap < 0
        refuse! "a cap of #{cap} is above a threshold of #{threshold} — raise the threshold in the same call" if cap > threshold

        before = "threshold #{child.light_day_threshold}, cap #{child.new_card_cap}"
        child.update! light_day_threshold: threshold, new_card_cap: cap

        "#{child.name}: #{before} → threshold #{threshold}, cap #{cap}"
      end
    end
  end
end
