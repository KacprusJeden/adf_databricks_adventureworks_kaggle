CREATE DATABASE synapsedb_kjeden;

DROP EXTERNAL DATA SOURCE bronze;
CREATE EXTERNAL DATA SOURCE bronze
WITH (
    LOCATION = 'https://storageaccountswec001.dfs.core.windows.net/bronze'
);

DROP EXTERNAL DATA SOURCE silver;
CREATE EXTERNAL DATA SOURCE silver
WITH (
    LOCATION = 'https://storageaccountswec001.dfs.core.windows.net/silver'
);

DROP EXTERNAL DATA SOURCE gold;
CREATE EXTERNAL DATA SOURCE gold
WITH (
    LOCATION = 'https://storageaccountswec001.dfs.core.windows.net/bronze'
);


DROP EXTERNAL DATA SOURCE [source];
CREATE EXTERNAL DATA SOURCE [source]
WITH (
    LOCATION = 'https://storageaccountswec001.blob.core.windows.net/source/'
);

drop EXTERNAL DATA SOURCE DESTINATION
CREATE EXTERNAL DATA SOURCE [destination]
WITH (
    LOCATION = 'https://storageaccountswec001.dfs.core.windows.net/destination'
);



CREATE EXTERNAL DATA SOURCE adls_data_source
WITH
(
    LOCATION = 'https://storageaccountswec001.dfs.core.windows.net/source/'
);



CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);

CREATE EXTERNAL FILE FORMAT delta_file_format
WITH (
    FORMAT_TYPE = PARQUET
);

CREATE EXTERNAL FILE FORMAT csv_format_comma
WITH
(
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS
    (
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '"',
        FIRST_ROW = 2
    )
);


USE synapsedb_kjeden
GO

CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'yourpassword'

CREATE DATABASE SCOPED CREDENTIAL kjedencreds WITH IDENTITY = 'Managed Identity';


CREATE SCHEMA kaggle_aw;

CREATE LOGIN kjedentech WITH PASSWORD 'yourpassword';
CREATE USER kjedentech FOR LOGIN kjedentech;

GRANT CREATE TABLE, CREATE VIEW, EXECUTE TO kjedentech;
GRANT CREATE, ALTER ON schema::kaggle_aww TO kjedentech;

ALTER ROLE db_datareader ADD MEMBER kjedentech;
ALTER ROLE db_datawriter ADD MEMBER kjedentech;

GRANT CREATE TABLE TO [kjedentech];
GRANT ALTER ON SCHEMA::dbo TO [kjedentech];
GRANT ALTER ON SCHEMA::kaggle_aw TO [kjedentech];

GRANT ALTER ON SCHEMA::kaggle_aw TO [kjedentech];
