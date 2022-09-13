-- Databricks notebook source
-- MAGIC %md
-- MAGIC ### Create delta table with SQL

-- COMMAND ----------

DROP TABLE IF EXISTS steam_presentation.game_infos;
CREATE TABLE IF NOT EXISTS steam_presentation.game_infos
USING DELTA
AS
SELECT
appid,
name,
release_date,
price,
currency,
metacritic_score,
developers,
publishers
FROM
steam_processed.games

-- COMMAND ----------

DESCRIBE steam_presentation.game_infos

-- COMMAND ----------

SELECT * FROM steam_presentation.game_infos WHERE price between 20 AND 70 AND publishers[0] != ''

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Publisher with most game releases 2021 with price above 20 €

-- COMMAND ----------

SELECT 
publishers[0] as publisher,
COUNT(publishers[0]) AS games_count,
DENSE_RANK() OVER(ORDER BY COUNT(publishers[0]) DESC) AS rank
FROM steam_presentation.game_infos 
WHERE price > 20 AND publishers[0] != '' AND release_date BETWEEN '2021-01-01' AND '2021-12-31'
GROUP BY publishers[0] 
HAVING games_count >= 3
ORDER BY games_count ASC


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Games with highest metascore

-- COMMAND ----------

SELECT
name,
DATE_PART('year', release_date) AS release_year,
metacritic_score,
price,
currency,
publishers[0] AS publisher
FROM steam_presentation.game_infos 
WHERE metacritic_score >= 70
ORDER BY metacritic_score ASC

-- COMMAND ----------



-- COMMAND ----------



-- COMMAND ----------


