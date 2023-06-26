module IotHelper
    def iot_transform(id)
        success = true
        @rec = Store.find(id) rescue nil
        if @rec.nil?
            puts "Error: for transformation cannot find ID: " + id.to_s
            return false
        end
        if @rec.item.is_a?(String)
            obj = JSON.parse(@rec.item)
        else
            obj = @rec.item
        end

        # perform SenML transformation with soya-web-cli
        response = HTTParty.post(SOYA_WEB_CLI_HOST + "api/v1/transform/" + SENML_TRANSFORMATION_SOYA,
            headers: { 'Content-Type'  => 'application/json' },
            body: obj.to_json )
        if response.code != 200
            puts "Error: failed SenML transformation for ID: " + id.to_s
            return false
        end
        response.parsed_response.each do |item|
            dri = Oydid.hash(Oydid.canonical(item.to_json))
            @i = Store.new(item: item.to_json, dri: dri, schema: SENML_TRANSFORMATION_SOYA)
            if @i.save
                iot_monitor(@i.id)
            else
                success = false
                puts "Error: failed to create new entry"
                puts item.to_json
            end
        end unless response.parsed_response.count == 0
        if !success
            return false
        end
        rec_meta = @rec.meta
        if rec_meta.nil?
            @rec.meta = {"processed": true}.to_json
        else
            if rec_meta.is_a?(String)
                rec_meta = JSON.parse(rec_meta)
            end
            @rec.meta = rec_meta.merge({"processed": true}).to_json
        end
        @rec.save

        return true
    end

    def iot_monitor(id)
        puts "monitor ID " + id.to_s
        @store = Store.find(id)
        if @store.item.is_a?(String)
            rec = JSON.parse(@store.item)
        else
            rec = @store.item
        end

        @checks = Store.where(schema: MONITOR_CHECKS)
        @checks.each do |check|
            if check.item.is_a?(String)
                item = JSON.parse(check.item)
            else
                item = check.item
            end
            begin
                if rec["n"] =~ /#{item["base"]}/
                    case item["operator"]
                    when "<="
                        if rec[item["attribute"]].to_i <= item["value"].to_i
                            puts "checked: " + item["title"].to_s
                            puts "  for " + item["base"].to_s
                            puts "  matched: " + item["attribute"].to_s + "(" + rec[item["attribute"]].to_s + ") <= " + item["value"].to_s
                            event_item = {}
                            event_dri = Oydid.hash(Oydid.canonical(event_item.to_json))
                            @event = Store.new(item: event_item, dri: event_dri, schema: SOYA_EVENT)
                            if @event.save
                                iot_event(@event.id)
                            else
                                success = false
                                puts "Error: failed to create new event"
                                puts item.to_json
                            end
                        end
                    end
                end
            rescue => ex
            end
        end unless @checks.count == 0
    end

    def iot_event(id)
        puts "process event ID " + id.to_s
    end

end
