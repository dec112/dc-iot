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
            rec_meta = @rec.meta
            if rec_meta.nil?
                if HAS_JSONB
                    @rec.meta = {"processed": true, "error": "failed SenML transformation"}
                else
                    @rec.meta = {"processed": true, "error": "failed SenML transformation"}.to_json
                end
            else
                if rec_meta.is_a?(String)
                    rec_meta = JSON.parse(rec_meta)
                end
                if HAS_JSONB
                    @rec.meta = rec_meta.merge({"processed": true, "error": "failed SenML transformation"})
                else
                    @rec.meta = rec_meta.merge({"processed": true, "error": "failed SenML transformation"}).transform_keys(&:to_s).to_json
                end
            end
            if @rec.save
                puts "Error: failed SenML transformation for ID: " + id.to_s + " (confirmed)"
            else
                puts "Error: failed SenML transformation for ID: " + id.to_s + " (unconfirmed)"
            end
            return false
        end
        response.parsed_response.each do |item|
            dri = Oydid.hash(Oydid.canonical(item.to_json))
            if HAS_JSONB
                @i = Store.new(item: item, meta:{"source-id": id}, dri: dri, schema: SENML_TRANSFORMATION_SOYA)
            else
                @i = Store.new(item: item.to_json, meta:{"source-id": id}.to_json, dri: dri, schema: SENML_TRANSFORMATION_SOYA)
            end
            if @i.save
                if !iot_monitor(@i.id)
                    success = false
                end
            else
                success = false
                puts "Error: failed to create new entry"
                puts item.to_json
            end
        end unless response.parsed_response.count == 0
        if success
            rec_meta = @rec.meta
            if rec_meta.nil?
                if HAS_JSONB
                    @rec.meta = {"processed": true}
                else
                    @rec.meta = {"processed": true}.to_json
                end
            else
                if rec_meta.is_a?(String)
                    rec_meta = JSON.parse(rec_meta)
                end
                if HAS_JSONB
                    @rec.meta = rec_meta.merge({"processed": true})
                else
                    @rec.meta = rec_meta.merge({"processed": true}).transform_keys(&:to_s).to_json
                end
            end
            if !@rec.save
                success = false
            end
        end
puts "completed transformation of ID: " + id.to_s + " (" + success.to_s + ")"
        return success
    end

    def iot_monitor(id)
        puts "monitor ID " + id.to_s
        success = true
        @store = Store.find(id) rescue nil
        if @store.nil?
            puts "Error: for monitoring cannot find ID: " + id.to_s
            return false
        end
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
                create_event = false
                if rec["n"] =~ /#{item["base"]}/
                    puts "found: '" + item["base"].to_s + "' in ID " + id.to_s
                    case item["operator"]
                    when "<="
                        if rec[item["attribute"]].to_i <= item["value"].to_i
                            puts "checked: " + item["title"].to_s + " for " + item["base"].to_s
                            puts "-> matched: " + item["attribute"].to_s + "(" + rec[item["attribute"]].to_s + ") <= " + item["value"].to_s
                            create_event = true
                        end
                    when "<"
                        if rec[item["attribute"]].to_i < item["value"].to_i
                            puts "checked: " + item["title"].to_s + " for " + item["base"].to_s
                            puts "-> matched: " + item["attribute"].to_s + "(" + rec[item["attribute"]].to_s + ") < " + item["value"].to_s
                            create_event = true
                        end
                    when ">="
                        if rec[item["attribute"]].to_i >= item["value"].to_i
                            puts "checked: " + item["title"].to_s + " for " + item["base"].to_s
                            puts "-> matched: " + item["attribute"].to_s + "(" + rec[item["attribute"]].to_s + ") >= " + item["value"].to_s
                            create_event = true
                        end
                    when ">"
                        if rec[item["attribute"]].to_i > item["value"].to_i
                            puts "checked: " + item["title"].to_s + " for " + item["base"].to_s
                            puts "-> matched: " + item["attribute"].to_s + "(" + rec[item["attribute"]].to_s + ") > " + item["value"].to_s
                            create_event = true
                        end
                    when "=="
                        if rec[item["attribute"]].to_s.downcase.strip == item["value"].to_s.downcase.strip
                            puts "checked: " + item["title"].to_s + " for " + item["base"].to_s
                            puts "-> matched: " + item["attribute"].to_s + "(" + rec[item["attribute"]].to_s + ") == " + item["value"].to_s
                            create_event = true
                        end
                    else
                        puts "ERROR: unknown operator '" + item["operator"].to_s + "'"
                    end
                end
                if create_event
                    identifier = rec["n"].sub(item["base_name"],"identifier") rescue nil
                    if identifier.nil?
                        sensor_id = nil
                    else
                        sensor_id = Store.where("item->>'n'= ?", identifier).last.item["v"] rescue nil
                    end
                    if sensor_id.nil?
                        sensor = {}
                    else
                        sensor = JSON.parse(Sensor.find_by_identifier(sensor_id.to_s).add_info) rescue {}
                    end
                    event_item = {
                            "trigger": item["trigger"], 
                            "record": rec, 
                            "monitor": item,
                            "sensor": sensor,
                            "ts": Time.now.utc.to_i
                    }.transform_keys(&:to_s)

                    event_meta = {
                        "schema": SOYA_EVENT,
                        "source-id": id
                    }.transform_keys(&:to_s)
                    event_dri = Oydid.hash(Oydid.canonical({"data": event_item, "meta": event_meta}.to_json))
                    if HAS_JSONB
                        @event = Store.new(item: event_item, meta: event_meta, dri: event_dri, schema: SOYA_EVENT)
                    else
                        @event = Store.new(item: event_item.to_json, meta: event_meta.to_json, dri: event_dri, schema: SOYA_EVENT)
                    end
                    if @event.save
                        if !iot_event(@event.id)
                            success = false
                        end
                    else
                        success = false
                        puts "Error: failed to create new event for '" + item["title"].to_s + "' on ID: " + id.to_s
                        puts item.to_json
                    end

                end
            rescue => ex
                success = false
            end
        end unless @checks.count == 0

        if success
            rec_meta = @store.meta
            if rec_meta.nil?
                if HAS_JSONB
                    @store.meta = {"processed": true}
                else
                    @store.meta = {"processed": true}.to_json
                end
            else
                if rec_meta.is_a?(String)
                    rec_meta = JSON.parse(rec_meta)
                end
                if HAS_JSONB
                    @store.meta = rec_meta.merge({"processed": true})
                else
                    @store.meta = rec_meta.merge({"processed": true}).transform_keys(&:to_s).to_json
                end
            end
            if !@store.save
                success = false
            end
        end
puts "completed monitoring of ID: " + id.to_s + " (" + success.to_s + ")"
        return success
    end

    def iot_event(id)
        puts "process event ID " + id.to_s
        success = true
        @store = Store.find(id) rescue nil
        if @store.nil?
            puts "Error: for events triggering cannot find ID: " + id.to_s
            return false
        end
        if @store.item.is_a?(String)
            rec = JSON.parse(@store.item)
            rec["meta"]={"dri": @store.dri, "schema": @store.schema}.transform_keys(&:to_s)
            if @store.meta.to_s.strip != ""
                rec["meta"]=rec["meta"].merge(JSON.parse(@store.meta)).transform_keys(&:to_s) rescue rec["meta"]
            end
        else
            rec = @store.item
            rec["meta"]={"dri": @store.dri, "schema": @store.schema}.transform_keys(&:to_s)
            if !@store.meta.nil?
                rec["meta"]=rec["meta"].merge(@store.meta).transform_keys(&:to_s) rescue rec["meta"]
            end
        end


        begin
            handlebars = Handlebars::Engine.new
            case rec["trigger"].to_s
            when "email"
                puts "event: '" + rec["trigger"].to_s + "' in ID " + id.to_s
                options = rec["monitor"]["trigger-options"] rescue nil
                if options.nil?
                    success = false
                else
                    template = handlebars.compile(options["to"].to_s)
                    to = template.call(rec["record"])
                    if to == ""
                        puts "Error: invalid TO address in ID " + id.to_s
                        success = false
                    end
                    template = handlebars.compile(options["subject"].to_s)
                    subject = template.call(rec["record"])
                    if subject == ""
                        puts "Error: missing SUBJECT in ID " + id.to_s
                        success = false
                    end
                    template = handlebars.compile(options["body"].to_s)
                    body = template.call(rec["record"])
                    if body == ""
                        puts "Error: missing SUBJECT in ID " + id.to_s
                        success = false
                    end

                    if success
                        puts "To: " + to
                        puts "Subject: " + subject
                        puts "Body: " + body
                        begin
                            EventMailer.send_email(to, subject, body).deliver_now
                        rescue
                            puts "Error: cannot send email for ID " + id.to_s
                            success = false
                        end
                        completed = {"to": to, "subject": subject, "body": body}
                    end

                end
            when "dec112sdk" # actually: dec112alert
                puts "event: '" + rec["trigger"].to_s + "' in ID " + id.to_s
                notify_object = {}
                notify_object = traverse_json(rec["monitor"]["trigger-options"], notify_object, rec)
                notify_object = add_location(notify_object, rec) rescue notify_object
                notify_object = JSON.parse(notify_object.to_json.gsub("'", "\"")) rescue nil
                if notify_object.nil?
                    success =false
                else
# echo '{"web":"https://www.ownyourdata.eu/de/impressum/","event":"Notruftaste auf IoT Sensor","title":"DEC112 Notruf via SDK","callId":"zQmWV7jYfjPxGvog5Z7k5X9p8kbrKSx5gxo4Dos6Kgie5P1","target":"ambulance","contact":"Demosetup OwnYourData, Tel: 0677 617 53 112","category":"health","headline":"Notruf durch IoT Sensor","language":"de-at","sensorId":"urn:dev:mac:fb518cffff5b9075manually_triggered","locations":[{"type":"Manual","civic":{"city":"Bad Vöslau","floor":"","street":"Michael Scherz-Straße","postalCode":"2540","houseNumber":"14"}}]}' | \
#  curl --cert fullchain.pem --key privkey.pem \
#       -H "Content-Type: application/json" -d @- \
#       -X POST https://app.test.dec112.eu:8081/api/v1/update/dec4iot-test

                    psap_url = ENV['PSAP_URL'] || "https://app.test.dec112.eu:8081/api/v1/update/dec4iot-test"
                    cmd  = 'TEMP_CERT_FILE=$(mktemp) && echo "' + ENV['FULLCHAIN'].to_s + '" > "$TEMP_CERT_FILE" && '
                    cmd += 'TEMP_KEY_FILE=$(mktemp) && echo "' + ENV['PRIVKEY'].to_s + '" > "$TEMP_KEY_FILE" && '
                    cmd += 'curl --cert "$TEMP_CERT_FILE" --key "$TEMP_KEY_FILE" '
                    cmd += '-H "Content-Type: application/json" -d ' + "'" + notify_object.to_json + "' "
                    cmd += '-X POST ' + psap_url
                    success, retVal = cmd_exec(cmd)

                    # puts "POST to https://app.test.dec112.eu:8081/api/v1/update/dec4iot-test"
                    # puts JSON.pretty_generate(notify_object)
                    if success
                        notify_object["psap_response"] = retVal
                    end
                    completed = notify_object
                end
            else
                puts "Error: unknown trigger '" + rec["trigger"].to_s + "'"
                success = false
            end
        rescue => ex
            success = false
        end

        if success
            if HAS_JSONB
                @store.item = @store.item.merge("completed": completed)
            else
                @store.item = JSON.parse(@store.item).merge("completed": completed).transform_keys(&:to_s).to_json
            end
            rec_meta = @store.meta
            if rec_meta.nil?
                if HAS_JSONB
                    @store.meta = {"processed": true}
                else
                    @store.meta = {"processed": true}.to_json
                end
            else
                if rec_meta.is_a?(String)
                    rec_meta = JSON.parse(rec_meta)
                end
                if HAS_JSONB
                    @store.meta = rec_meta.merge({"processed": true})
                else
                    @store.meta = rec_meta.merge({"processed": true}).transform_keys(&:to_s).to_json
                end
            end
            if !@store.save
                success = false
            end
        end
puts "completed Event-ID: " + id.to_s + " (" + success.to_s + ")"
        return success
    end

    def cmd_exec(cmd)
        require 'open3'
        out = nil
        exit_status = nil
        Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid # pid of the started process.
          out = stdout.gets(nil)
          exit_status = wait_thr.value # Process::Status object returned.
        }
        if exit_status == 0
            retVal = JSON.parse(out.to_s) rescue nil
            if retVal.nil?
                return [false, out.to_s]
            else
                return [true, retVal]
            end
        else
            return [false, out.to_s]
        end
    end

    def traverse_json(obj, notify_object, rec)
        handlebars = Handlebars::Engine.new
        if obj.is_a? Hash
            obj.each do |key, value|
                if value.is_a? Hash
                    notify_object[key] = traverse_json(value, {}, rec)
                elsif value.is_a? Array
                    notify_object[key] = [traverse_json(value, {}, rec)]
                else
                    notify_object[key] = handlebars.compile(value.to_s).call(
                        rec["record"].merge({"meta"=>rec["meta"],"sensor"=>rec["sensor"]})) rescue value
                end
            end
        elsif obj.is_a? Array
            obj.each_with_index do |value, index|
                notify_object = traverse_json(value, {}, rec)
            end
        end
        return notify_object
    end

    def add_location(notify_object, rec)
        identifier = rec["record"]["n"].sub(rec["monitor"]["base_name"],"")
        latitudes = Store.where("item ? :key AND item->>:key LIKE :value_pattern", 
                                key: 'n', 
                                value_pattern: identifier.sub(/:*$/, '') + '%latitude')
                         .order(:id).last(10).pluck(:item)
        longitudes = Store.where("item ? :key AND item->>:key LIKE :value_pattern", 
                                key: 'n', 
                                value_pattern: identifier.sub(/:*$/, '') + '%longitude')
                         .order(:id).last(10).pluck(:item)
        accuracies = Store.where("item ? :key AND item->>:key LIKE :value_pattern", 
                                key: 'n', 
                                value_pattern: identifier.sub(/:*$/, '') + '%accuracy')
                         .order(:id).last(10).pluck(:item)
        sorted_lat = latitudes.sort_by { |item| item["t"] }
        sorted_lon = longitudes.sort_by { |item| item["t"] }
        sorted_acc = accuracies.sort_by { |item| item["t"] }

        merged = sorted_lat.zip(sorted_lon).map do |la, lo|
            if la && lo && la["t"] == lo["t"]
                {
                    "longitude" => lo["v"],
                    "latitude" => la["v"],
                    "t" => la["t"]
                }
            end
        end
        combined = merged.map do |loc|
            acc = sorted_acc.find { |obj| obj["t"] == loc["t"]}
            if acc.nil?
                {
                    "longitude" => loc["longitude"],
                    "latitude" => loc["latitude"],
                    "altitude" => nil,
                    "radius" => nil,
                    "timestamp" => Time.at(loc["t"].to_f.to_i).iso8601,
                    "method" => "GPS"
                }
            else
                {
                    "longitude" => loc["longitude"],
                    "latitude" => loc["latitude"],
                    "altitude" => nil,
                    "radius" => acc["v"],
                    "timestamp" => Time.at(loc["t"].to_f.to_i).iso8601,
                    "method" => "GPS"
                }
            end
        end

        notify_object["locations"] += combined
        return notify_object
    end
end
