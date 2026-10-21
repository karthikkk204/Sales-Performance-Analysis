import os
from pathlib import Path
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine
import kagglehub

# 1. Extract Data from Kaggle / Local Directory
def extract_data(path):
    directory_path = Path(path)
    csv_files = list(directory_path.glob("*.csv"))
    
    file_names = [file.name for file in csv_files]
    
    new_name_list = []
    for file_name in file_names:
        # Clean file names (remove 'adventureworks_', lowercase, remove '.csv')
        clean_name = file_name.lower().replace("adventureworks_", "").split(".")[0]
        new_name_list.append(clean_name)
        
    table_dict = {}
    for name, file in zip(new_name_list, csv_files):
        table_dict[name] = pd.read_csv(file, encoding="latin1")
        
    return table_dict

# Example path setup (adjust to your local download directory)
path = "path_to_downloaded_adventureworks_files"
ext_data = extract_data(path)

# 2. Load Data into MySQL
def load_data(ext_data):
    load_dotenv()
    username = os.getenv("MYSQL_USERNAME")
    password = os.getenv("MYSQL_PASSWORD")
    hostname = "localhost"
    database = "adworks_raw"

    engine = create_engine(f"mysql+pymysql://{username}:{password}@{hostname}/{database}")
    
    for table_name, df in ext_data.items():
        df.to_sql(table_name, con=engine, if_exists="replace", index=False)
        print(f"{table_name} successfully imported")

# Execute load function
load_data(ext_data)
```[cite: 1]

---

### Part 2: MySQL Setup & Staging Transformation Queries (MySQL Workbench)

Run these queries sequentially in MySQL Workbench:

#### Step A: Initial Database & User Setup (Run via Command Line / Root)
```sql
CREATE DATABASE adworks_raw;
CREATE DATABASE adworks_staging;
CREATE DATABASE adworks_analytics;

CREATE USER 'anidu'@'localhost' IDENTIFIED BY '123456';
CREATE USER 'yakubu'@'localhost' IDENTIFIED BY '123456';

GRANT ALL PRIVILEGES ON adworks_raw.* TO 'anidu'@'localhost';
GRANT ALL PRIVILEGES ON adworks_staging.* TO 'anidu'@'localhost';
GRANT ALL PRIVILEGES ON adworks_analytics.* TO 'anidu'@'localhost';

GRANT SELECT ON adworks_analytics.* TO 'yakubu'@'localhost';
FLUSH PRIVILEGES;