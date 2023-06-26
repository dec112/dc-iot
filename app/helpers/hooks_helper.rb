module HooksHelper
    include IotHelper
    def write_hook(data)
        iot_transform(data[:id])
    end

    def read_hook(data)

    end

    def update_hook(data)

    end

    def delete_hook(data)

    end

end
