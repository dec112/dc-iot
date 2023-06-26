class TriggersController < ApplicationController
    include IotHelper

    # GET /trigger
    def trigger
        success = true
        # transformation trigger
        begin
            if Rails.configuration.database_configuration[Rails.env]["adapter"] == "postgresql"
                @unprocessed = Store.where.not("meta @> '{\"processed\": true}'")
            else
                @unprocessed = Store.last(5)
            end
            @unprocessed.each do |item|
                if !iot_transform(item.id)
                    success = false
                end
                if item.created_at < Time.now-2.minutes
                    # trigger alarm
                end
            end unless @unprocessed.count == 0

            if success
                # trigger heart-beat
                puts "Transformation triggered"
            end
        rescue => ex
            puts "Transformation Error: " + ex.message
            success = false
        end

        # monitoring trigger
        begin

        rescue => ex
            puts "Monitoring Error: " + ex.message
            success = false
        end

        # event trigger
        begin

        rescue => ex
            puts "Event Error: " + ex.message
            success = false
        end

        render json: {"completed": success},
               status: 200

    end
end
