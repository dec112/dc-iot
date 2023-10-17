SOYA_WEB_CLI_HOST = "https://soya-web-cli.ownyourdata.eu/"
SENML_TRANSFORMATION_SOYA = "SenML_Transformation"
SOYA_EVENT = "IoT_Event"
MONITOR_CHECKS = ["IoT_Monitoring"]

HAS_JSONB = (Rails.configuration.database_configuration[Rails.env]["adapter"] == "postgresql")