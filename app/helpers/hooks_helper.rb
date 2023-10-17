module HooksHelper
    include IotHelper
    def write_hook(data)
        schema = Store.find(data[:id]).schema.to_s rescue ""
        if schema == ""
            iot_transform(data[:id])
        end
    end

    def read_hook(data)

    end

    def update_hook(data)

    end

    def delete_hook(data)

    end

end
