# `dc-iot` - DEC112 IoT integration

This repository provides a comprehensive solution for the monitoring of IoT devices. With this software, users can integrate sensors and monitor the status, performance, and any anomalies. The system continuously collects data from the connected devices and analyzes it to determine if they are functioning correctly or if potential problems might arise. Upon detecting unusual activities or when device parameters fall outside the established normal range, alarms are immediately triggered. These alerts can be relayed through various channels such as email, or alerting through the DEC112 ESInet. The repository includes both the code for data collection and analysis, as well as a user-friendly interface for configuring monitoring settings and alarm conditions. The aim of this project is to provide a robust and scalable solution to ensure the efficiency and security of IoT networks.

<img align="center" src="https://raw.githubusercontent.com/dec112/dc-iot/main/app/assets/images/system.png" height="400">

Content:
* [Further Resources](#further-resources)
* [Developer Information](#developer-information)
    * [Deployment](#deployment)
    * [Sample Data and Typical Workflow](#sample-data-and-typical-workflow)
* [Issues](#issues)
* [About](#about)
* [License](#license)

## Further Resources
* Project description: https://www.netidee.at/dec4iot    
* Semantic Container: https://github.com/OwnYourData/semcon    
* Blogpost on Monitoring (in German): https://www.netidee.at/dec4iot/system-monitoring-fuer-dec4iot

## Developer Information

### Deployment

#### Docker Images
A pre-built Docker image [`oydeu/dc-iot`](https://hub.docker.com/r/oydeu/dc-iot) is available on Dockerhub and can be started locally with the following command:
```bash
docker run -d --name iot -p 8080:3000 oydeu/dc-iot:latest
```
YAML files for deployment on kubernetes are [available here](/dec112/dc-iot/tree/main/kubernetes).
To provide certificates necessary for connecting to the NG112 alerting you can use the following commands (assuming credentials available in `creds/`:
```bash
kubectl create configmap fullchain-config --from-file=creds/fullchain.pem
kubectl create configmap privkey-config --from-file=creds/privkey.pem
```

#### Configuration Options
Data container backend:
* `DC_DB`: type of database; available options: `local` for internal SQLite, `postgres` for connection to local PostgreSQL instance, `kubernetes` for high-availability PostgreSQL cluster
* `DB_HOST`: hostname of DB
* `DB_NAME`: name of database
* `DB_USER`: user for connecting to database
* `POSTGRES_PASSWORD`: password for connecting to database

Sending emails:
* `SMTP_HOST`: hostname or IP address of the SMTP server used for sending email
* `SMTP_DOMAIN`: domain name used for identifying the sending domain during email transmission via the SMTP server
* `SMTP_USER`: username required for authenticating with the SMTP server when sending email
* `SMTP_PASSWORD`: password required for authenticating with the SMTP server when sending email
* `FROM_MAIL`: mail address to be shown as sender

trigger NG112 alerts:
* `PSAP_URL`: address to send NG112 alerts to (example: `https://app.test.dec112.eu:8081/api/v1/update/dec4iot-test)
* `FULLCHAIN`: full chain of certificates, including the server certificate followed by any intermediate certificates, required to establish a secure connection to a service
* `PRIVKEY`: private key associated with the server certificate, used to securely connect to and authenticate with a service

### Sample Data and Typical Workflow
The following code assumes a deployed and configured instance of `oydeu/dc-iot` on https://dec4iot.data-container.net. 

#### Configure Sensor
1) Manage sensors on `HOST/sensors`
    https://dec4iot.data-container.net/sensors
2) Create new sensors on `HOST/sensors/new`
    https://dec4iot.data-container.net/sensors/new
3) Enter sensor data:
    * **Identifier:** default is record ID, max. 4 characters
        example: `1`
    * **Service endpoint:** information for the sensor about where data should be sent, max. 15 characters
        example: `dec112.at/iot` (forwards to: https://dec4iot.data-container.net/api/data)
    * **Additional information:** additional information that can be used when triggering events (e.g., floor), format: JSON
        example:
        ```json
        {
            "info": "Bangle.js 9075",
            "target": "police",
            "location": {
                "city": "Bad Vöslau",
                "zip": "2540",
                "street": "Michael Scherz-Straße",
                "number": "14"
            }
        }
        ```
4) Link sensor: scan QR-code to initialize and link sensor
    example: https://dec4iot.data-container.net/sensors/37

#### Sequence for Email Event
**Assumptions:**    
* sensor with `identifier: 5` configured ([record](https://dec4iot.data-container.net/sensors/37))
* monitoring for low battery alarm configured    
    https://dec4iot.data-container.net/api/data?id=49071
    ```json
    {
      "base": "batt$",
      "base_name": "batt",
      "title": "Batterie Warnung",
      "attribute": "v",
      "operator": "<=",
      "value": "20",
      "trigger": "email",
      "trigger-options": {
        "to": "christoph.fabianek@gmail.com",
        "body": "{{n}} ist unter 20% (aktuell: {{v}})",
        "title": "E-Mail zu niedrigem Batteriestand",
        "subject": "Niedriger Batteriestand"
      }
    }
    ```
<details><summary>Command to create a new monitoring record</summary>

```bash=
echo '{"title":"titel",
       "base":"batt$",
       "base_name":"batt",
       "attribute":"v",
       "operator": "<=",
       "value":"20",
       "trigger":"email", 
       "trigger-options": {
          "title":"Low battery warning email",
          "to":"user@host.com", 
           "subject":"Low battery",
           "body":"{{n}} ist unter 20% (aktuell: {{v}})"}, 
       "meta": {"schema":"IoT_Monitoring",
                "processed":true}}' | \
curl -H 'Content-Type: application/json' -d @- \
     -X POST https://dec4iot.data-container.net/api/data
```

SOyA structure for `IoT_Monitoring`: https://soya.ownyourdata.eu/IoT_Monitoring/yaml

</details>

**Sequence:**
1) Sensor sends record    
    relevant: `{"n":"batt","u":"%EL","v":19}` 
    <details><summary>Command</summary>
    
    ```bash=
    echo '[{"n":"identifier","v":5,"bn":"urn:dev:mac:fb518cffff5b9075","bt":1685286440},{"n":"batt","u":"%EL","v":19},{"n":"heading","v":183.53101568878},{"n":"temperature","v":33.05662536621},{"n":"pressure","u":"hPa","v":973.95376105848},{"n":"altitude","u":"m","v":332.42848559087},{"n":"steps","u":"counter","v":21},{"n":"manually_triggered","vb":true}]' | \
    curl -H "Content-Type: application/json" -d @- \
         -X POST https://dec4iot.data-container.net/api/data
    ```

    </details>
2) Record is stored    
    https://dec4iot.data-container.net/api/data?id=57377
3) Data (SenML encoded) is split up into components:    
    (meta data references `source-id`)    
    * Sensor Identifier (`v:5`): https://dec4iot.data-container.net/api/data?id=57378
    * Battery: https://dec4iot.data-container.net/api/data?id=57379
    * Heading: https://dec4iot.data-container.net/api/data?id=57381
    * Temperature: https://dec4iot.data-container.net/api/data?id=57382
    * Pressure: https://dec4iot.data-container.net/api/data?id=57383
    * Altitude: https://dec4iot.data-container.net/api/data?id=57384
    * Steps: https://dec4iot.data-container.net/api/data?id=57385
    * Button pressed: https://dec4iot.data-container.net/api/data?id=57386
4) Monitoring generates an event record for falling below the battery threshold value and sends email    
    https://dec4iot.data-container.net/api/data?id=57380

#### Sequence for NG112 Alert
**Assumptions:**    
* sensor with `identifier: 5` configured ([record](https://dec4iot.data-container.net/sensors/37))
* Monitoring configured for "press button"    
    https://dec4iot.data-container.net/api/data?id=49071
    ```json
    {
        "base": "manually_triggered$",
        "base_name": "manually_triggered",
        "title": "Notruftaste",
        "attribute": "vb",
        "value": "true",
        "operator": "==",
        "trigger": "dec112sdk",
        "trigger-options": {
            "title": "DEC112 Notruf via SDK",
            "target": "{{#if sensor.target}}{{sensor.target}}{{else}}ambulance{{/if}}",
            "callId": "{{meta.dri}}",
            "sensorId": "{{n}}",
            "language": "de-at",
            "category": "{{#if sensor.category}}{{sensor.category}}{{else}}health{{/if}}",
            "event": "Notruftaste auf IoT Sensor",
            "contact": "Demosetup OwnYourData, Tel: 0677 617 53 112",
            "web": "https://www.ownyourdata.eu/de/impressum/",
            "headline": "Notruf durch IoT Sensor",
            "locations": [{
                "type": "Manual",
                "civic": {
                    "street": "Michael Scherz-Straße",
                    "houseNumber": "14",
                    "floor": "",
                    "postalCode": "2540",
                    "city": "Bad Vöslau"
                }
            }]
        }
    }
    ```

**Sequence:**    
1) Sensor sends record    
    relevant: `{"n":"manually_triggered","vb":true}` 
    <details><summary>Command - Sensor 5</summary>
    
    ```bash=
    echo '[{"n":"identifier","v":5,"bn":"urn:dev:mac:fb518cffff5b9075","bt":1685286440},{"n":"batt","u":"%EL","v":19},{"n":"heading","v":183.53101568878},{"n":"temperature","v":33.05662536621},{"n":"pressure","u":"hPa","v":973.95376105848},{"n":"altitude","u":"m","v":332.42848559087},{"n":"steps","u":"counter","v":21},{"n":"manually_triggered","vb":true}]' | \
    curl -H "Content-Type: application/json" -d @- \
         -X POST https://dec4iot.data-container.net/api/data
    ```
    </details>

    <details><summary>Command - Sensor 6</summary>
    
    ```bash=
    echo '[{"n":"identifier","v":6,"bn":"urn:dev:mac:fb518cffff5b9075","bt":1696077022},{"n":"batt","u":"%EL","v":39},{"n":"heading","v":129.52263127117},{"n":"temperature","v":33.32276407877},{"n":"pressure","u":"hPa","v":981.2715188464},{"n":"altitude","u":"m","v":269.71078897221},{"n":"steps","u":"counter","v":0},{"n":"manually_triggered","vb":true}]' | \
    curl -H "Content-Type: application/json" -d @- \
         -X POST https://dec4iot.data-container.net/api/data
    ```
    </details>

2) Record is stored    
    https://dec4iot.data-container.net/api/data?id=57377
3) Data (SenML encoded) is split up into components:    
    (meta data references `source-id`)    
    * Button pressed: https://dec4iot.data-container.net/api/data?id=57386
4) Monitoring generates an event record    
    https://dec4iot.data-container.net/api/data?id=57387
5) Validate on DEC112 webclient:
    URL: https://psap.test.dec112.eu/
    Server: `wss://psap.test.dec112.eu:8091/api/v1`

&nbsp;    

## Issues

Please report bugs and suggestions for new features using the [GitHub Issue-Tracker](https://github.com/dec112/dc-iot/issues) and follow the [Contributor Guidelines](https://github.com/twbs/ratchet/blob/master/CONTRIBUTING.md).

If you want to contribute, please follow these steps:

1. Fork it!
2. Create a feature branch: `git checkout -b my-new-feature`
3. Commit changes: `git commit -am 'Add some feature'`
4. Push into branch: `git push origin my-new-feature`
5. Send a Pull Request

&nbsp;    

## About  

<img align="right" src="https://raw.githubusercontent.com/dec112/dc-iot/main/app/assets/images/netidee.jpeg" height="150">This project has received funding from [Netidee Call 17](https://netidee.at).

<br clear="both" />

## License

[MIT License 2023 - DEC112](https://raw.githubusercontent.com/dec112/dc-iot/main/LICENSE)
