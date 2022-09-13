# ELT Project "Its Azure Time" Steam Games

This is a small ELT project i made on the Azure Cloud.\
I will go through this step by step so you can follow along.
\
\
![tools](https://user-images.githubusercontent.com/108484798/189981171-ec61e796-05bc-4c74-9e75-7b1a02748734.png)

### Tools used:
- [Azure Cloud](https://azure.microsoft.com/)
- [Azure Virtual Machine](https://azure.microsoft.com/en-us/services/virtual-machines/)
- [Azure Databrick](https://azure.microsoft.com/en-us/products/databricks/#overview)
- [Azure Data Lake](https://azure.microsoft.com/en-us/services/storage/data-lake-storage/)
- [Azure Data Factory](https://azure.microsoft.com/en-us/products/data-factory/)
- [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/)
- [Delta Lake](https://docs.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-what-is-delta-lake)
- [MS Power BI](https://powerbi.microsoft.com/en-us/)
- [Python](https://www.python.org/)

### Let's begin
First I made a Python tool to download a list with all games on the Steam gaming platform.


* [GetSteamGames](https://github.com/PatrickDegner/GetSteamGames) - found my repository

![image](https://user-images.githubusercontent.com/108484798/189935791-2e08f432-70fd-4291-b14d-c861950ec14a.png)

Now i have needed a place to run this Script.
1. So let's create an Azure Virtual Machine in the Cloud.\
https://docs.microsoft.com/de-de/azure/virtual-machines/windows/quick-create-portal \
I have chosen a small size with Windows to just run the app and collect the data.


\
Here I used the system assigned managed identity to be able to use azcopy identy on the Virtual Machine\
You need to assign Permissions to your Data Lake ressource. "Storage Blob Data Contributor"
![image](https://user-images.githubusercontent.com/108484798/189943477-01815de3-ac54-45ab-afde-7225b09c6bd8.png)


But where to Store the data in the cloud to work with it? A VM Disk is not the best choice.

2. A storage is needed which i can use for the full ELT process. Yes its Azure Data Lake Gen2\
https://docs.microsoft.com/en-us/azure/storage/blobs/create-data-lake-storage-account \
There is also a good tool to help with working on storage. (Azure Storage Explorer)\
![image](https://user-images.githubusercontent.com/108484798/189942304-b47531ae-41fb-471a-88d2-fec135e532bb.png)


How to get my data into the Data Lake ?\
I wrote a Powershell script to help with that.

3. This script will copy the current gamelist file to a transfer folder and then upload it into the Datalake.\
This will be automated later in Data Factory.
```sh
Copy-Item -Path <from path>\gamelist.json -Destination <to path>\transfer -Recurse -force
azcopy.exe login --identity
azcopy.exe copy "<from path>\gamelist.json" "https://<storage name>.blob.core.windows.net/<folder>/" --overwrite=True
```


How to go from here? The data gets extracted and we can even load the raw file with the script.

4. Databricks is used to transform the data and Azure Key Vault to secure the secrets.\
So i saved the secrets of Databricks in the Key Vault.\
client_id, tenant_id, client_secret\
![image](https://user-images.githubusercontent.com/108484798/189952899-b8817474-fc24-4f4a-83e2-eac164789e8c.png) \
Checkout my [Databricks notebook](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/1.setup/mount_adls.ipynb) for this. \
But if you have any problems, the Databricks website will help you too.\
https://docs.databricks.com/data/data-sources/azure/azure-storage.html


Now the Spark and SQL fun begins :)

5. Create a raw (bronze layer) [Database](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/3.load/0.create_raw_database.sql) \
Create a processed (silver layer) [Database](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/3.load/1.create_processed_database.sql) \
Finally transform some data!\
In tried to explain most stuff in this [Notebook](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/3.load/2.ingest_steam_file.ipynb) for you.

First I have read the full json file, select the columns I need and add a creation as well as an update timestamp.
```sh
selected_games_df = games_df.select(
                                    games_df["appid"],
                                    games_df["name"],
                                    games_df["release_date"],
                                    games_df["price"],
                                    games_df["currency"],
                                    games_df["short_description"],
                                    games_df["header_image"],
                                    games_df["windows"],
                                    games_df["mac"],
                                    games_df["linux"],
                                    games_df["metacritic_score"],
                                    games_df["developers"],
                                    games_df["publishers"],
                                    games_df["categories"],
                                    games_df["genres"])\
                                    .withColumn("release_date", regexp_replace("release_date", ",", ''))\
                                    .withColumn("release_date", to_date("release_date", format='d MMM yyyy'))\
                                    .withColumn("create_timestamp",current_timestamp())\
                                    .withColumn("update_timestamp",lit(""))
```
After this I have dropped the rows with bad release_date (i want to track the year mostly)
```sh
final_df = selected_games_df.na.drop(subset=["release_date"])
```

Now it becomes a bit tricky:
* Check if table exists
* If table exists check for old and new results
* Update timestamp if appid already exists
* Merge everything new if row don't exist
* Write dataframe to delta table in Silver Layer.
```sh
if (spark._jsparkSession.catalog().tableExists("steam_processed.games")):
    deltaTable = DeltaTable.forPath(spark, f"{processed_path}/games")
    deltaTable.alias("tgt").merge(
        final_df.alias("src"),
        "tgt.appid = src.appid") \
      .whenMatchedUpdate(set={"update_timestamp": current_timestamp()}) \
      .whenNotMatchedInsertAll()\
      .execute()
else:
    final_df.write.mode("overwrite").format("delta").saveAsTable("steam_processed.games")
```

After this, I worked on the processed (silver layer) to create some tables for my analysis.

6. First [create](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/4.transform/0.create_presentation_database.sql) a presentation db
```sh
CREATE DATABASE IF NOT EXISTS steam_presentation 
LOCATION "/mnt/patricklakegen2/presentation"
```
I have done 3 Notebooks for my analysis and have written them into Delta Tables in presentation layer (gold layer)
* [Game List by Year (spark)](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/4.transform/1.game_list_by_year.ipynb)
* [Games by PC platform (spark)](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/4.transform/2.games_by_pc_platforms.ipynb)
* [Mutiple Game Infos (SQL)](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/4.transform/3.game_infos.sql)


But can all this be automated? Sure! with Azure Data Factory orchestration.

7. In Data Factory I created 4 Pipelines. 3 for ELT and 1 to run the pipelines together.\
Let me show you what I did here.\
![image](https://user-images.githubusercontent.com/108484798/189960372-96aefe49-a9c4-4069-86d7-54bad6710cd2.png)

Remember the Powershell script on the Virtual Machine? I made a Web activity for this.\
https://docs.microsoft.com/en-us/azure/data-factory/control-flow-web-activity

The contribution Role is needed for Data Factory on the Virtual Machine.\
In url I have put:
```sh
https://management.azure.com/subscriptions/<subscription id>/resourceGroups/<resource name>/providers/Microsoft.Compute/virtualMachines/<VM name>/runCommand?api-version=2021-07-01
```
![image](https://user-images.githubusercontent.com/108484798/189961715-171a214b-b778-4777-ad61-aa86952fdead.png)

When I run this now, the activity triggers the Powershell script and the file will be put in the raw db folder.

In the next Pipeline I just trigger the load [notebook](https://github.com/PatrickDegner/ItsAzureTimeELT/blob/main/3.load/2.ingest_steam_file.ipynb) from step 5 \
![image](https://user-images.githubusercontent.com/108484798/189962475-320f33d8-526c-40da-8bf4-3305a51ceb9b.png)\
After this comes the Transform Pipeline.\
In this, all transform notebooks are triggered.\
![image](https://user-images.githubusercontent.com/108484798/189963045-5d530632-faed-494b-8d0b-0be26104f42b.png)\
Last but not least I made this fourth Pipeline to just trigger them all after each other.\
![image](https://user-images.githubusercontent.com/108484798/189963264-b4e3b6e0-19f0-4356-98fd-bd67ebd8fb83.png)\
To run these Notebooks on Azure Data Factory is pretty easy.\
Have a look here.\
https://docs.microsoft.com/en-us/azure/data-factory/transform-data-using-databricks-notebook\

Now its time for the Pipeline to run fully automatically.
Create a scheduled trigger:
![image](https://user-images.githubusercontent.com/108484798/189964016-7629b742-fc14-40be-8286-1f9c083014a1.png)


Some insight in the data maybe?

8. Power BI will help us here. \
Linking Power BI and Azure Databricks is really straight forward.\
I have used a Personal Access Token in Databricks\
Just go to Account Settings in Databricks and find this Button\
![image](https://user-images.githubusercontent.com/108484798/189965281-64573c17-3c3b-46a2-9173-194a928ccbd0.png)\
Now use the Token in Power BI as you see in the image below.\
![image](https://user-images.githubusercontent.com/108484798/189964904-ac222f5b-6369-4cb6-afc0-d2e947477707.png)\


Following here will be Power BI screenshots and informations.\
Coming soon....
