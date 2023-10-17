class TriggersController < ApplicationController
    include IotHelper

    # GET /trigger
    def trigger
        success = true
        # transformation trigger
        begin
            if HAS_JSONB
                @unprocessed = Store.where("(NOT (meta->>'processed' = ?) OR meta IS NULL) AND schema IS NULL", 'true')
            else
                @unprocessed = Store.where("schema IS NULL").last(5)
            end
            if @unprocessed.count > 100
                @unprocessed = @unprocessed.first(100)
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
            # !!!fix-me
            # if Rails.configuration.database_configuration[Rails.env]["adapter"] == "postgresql"
            #     @unprocessed = Store.where.not("meta @> '{\"processed\": true}'")
            # else
            #     @unprocessed = Store.last(5)
            # end

            # @events = Store.where(schema: SOYA_EVENT)
            # @events.each do |event|
            #     if !iot_event(event.id)
            #         success = false
            #     end
            #     if item.created_at < Time.now-2.minutes
            #         # trigger alarm
            #     end
            # end unless @unprocessed.count == 0

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
