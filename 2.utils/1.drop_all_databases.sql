-- Databricks notebook source
-- MAGIC %md
-- MAGIC ##### Drop all the tables

-- COMMAND ----------

DROP DATABASE IF EXISTS steam_raw CASCADE;

-- COMMAND ----------

CREATE DATABASE IF NOT EXISTS steam_raw
LOCATION "/mnt/patricklakegen2/raw";

-- COMMAND ----------

DROP DATABASE IF EXISTS steam_processed CASCADE;

-- COMMAND ----------

CREATE DATABASE IF NOT EXISTS steam_processed
LOCATION "/mnt/patricklakegen2/processed";

-- COMMAND ----------

DROP DATABASE IF EXISTS steam_presentation CASCADE;

-- COMMAND ----------

CREATE DATABASE IF NOT EXISTS steam_presentation 
LOCATION "/mnt/patricklakegen2/presentation";
