-- Databricks notebook source
-- MAGIC %md
-- MAGIC #### Create raw database for raw_tables

-- COMMAND ----------

CREATE DATABASE IF NOT EXISTS steam_raw
LOCATION "/mnt/patricklakegen2/raw"

-- COMMAND ----------

DESC DATABASE steam_raw

-- COMMAND ----------

DROP DATABASE IF EXISTS steam_raw;

-- COMMAND ----------


