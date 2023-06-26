class CreateSensors < ActiveRecord::Migration[7.0]
  def change
    create_table :sensors do |t|
      t.string :sensor_id
      t.string :identifier
      t.string :service_endpoint
      t.string :add_info

      t.timestamps
    end
  end
end
