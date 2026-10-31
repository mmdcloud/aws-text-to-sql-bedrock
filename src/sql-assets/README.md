# SQL Knowledge Base & Vector Embedding Assets

This directory contains standardized SQL domain assets designed specifically for ingestion into **Amazon Bedrock Knowledge Bases** and vector databases (Pinecone / OpenSearch Serverless).

These assets enable LLMs (Amazon Titan Text Premier / Claude) to generate accurate, secure, read-only MySQL 8.0 queries from natural language business questions.

---

## Asset Manifest

| File | Type | Target Purpose |
| :--- | :---: | :--- |
| [`01_schema_definitions.sql`](./01_schema_definitions.sql) | DDL (SQL) | Complete table DDL with indexes, foreign keys, and column comments. |
| [`01_schema_documentation.md`](./01_schema_documentation.md) | Markdown | Structured data dictionary with column types, allowed enum values, and field semantics. Optimized for vector chunking. |
| [`02_entity_relationships.md`](./02_entity_relationships.md) | Markdown | ER diagram, join conditions, foreign key chains, cardinality, and multi-table traversal guidelines. |
| [`03_business_metrics_glossary.md`](./03_business_metrics_glossary.md) | Markdown | Mapping of business concepts (GMV, Net Revenue, AOV, LTV, Churn Rate, MRR, ARR) directly to exact SQL formulas. |
| [`04_few_shot_examples.md`](./04_few_shot_examples.md) | Markdown | Realistic Question $\rightarrow$ SQL $\rightarrow$ Explanation pairs for semantic few-shot vector retrieval. |
| [`05_mysql_dialect_guidelines.md`](./05_mysql_dialect_guidelines.md) | Markdown | Dialect rules for MySQL 8.0, strict read-only security guards, date math, null handling, and limits. |
| [`06_seed_sample_data.sql`](./06_seed_sample_data.sql) | SQL Seed | Executable insert script populating customers, orders, items, payments, subscriptions, and reviews for immediate query testing. |

---

## How Amazon Bedrock Uses These Assets

```
+-------------------------------------------------------------+
|                     src/sql-assets/*.md                     |
|  (Schemas, ER Joins, Business Glossary, Few-Shot Examples)  |
+-------------------------------------------------------------+
                              |
                              v  (S3 Upload)
+-------------------------------------------------------------+
|       S3 Bucket: bedrock-knowledge-base-data-source-*       |
+-------------------------------------------------------------+
                              |
                              v  (Bedrock Knowledge Base Ingestion)
+-------------------------------------------------------------+
|    Amazon Titan Embeddings v2 (amazon.titan-embed-text-v2)  |
+-------------------------------------------------------------+
                              |
                              v  (Vector Store Upsert)
+-------------------------------------------------------------+
|             Pinecone Vector Database / Index                |
+-------------------------------------------------------------+
                              |
                              v  (Runtime Retrieval & Generation)
+-------------------------------------------------------------+
|    User Question: "What was our net revenue last month?"    |
|    Vector Search Retrieves: 03_business_metrics + few-shots |
|    Titan Text Premier Generates: SELECT SUM(total_amount).. |
+-------------------------------------------------------------+
```

---

## Quick Start: Syncing to AWS S3 & Bedrock

### 1. Identify the Bedrock S3 Data Source Bucket
From the `terraform/` directory:
```bash
BUCKET_NAME=$(terraform output -raw bedrock_knowledge_base_bucket_name 2>/dev/null || aws s3 ls | grep bedrock-knowledge-base-data-source | awk '{print $3}')
echo "Target S3 Bucket: ${BUCKET_NAME}"
```

### 2. Upload Markdown & SQL Assets to S3
```bash
aws s3 sync src/sql-assets/ s3://${BUCKET_NAME}/sql-knowledge/ \
    --exclude "*" \
    --include "*.md" \
    --include "*.sql"
```

### 3. Sync the Bedrock Knowledge Base Ingestion Job
```bash
# Ingest updated documentation into Pinecone via Bedrock Agent Runtime
aws bedrock-agent start-ingestion-job \
    --knowledge-base-id <YOUR_KNOWLEDGE_BASE_ID> \
    --data-source-id <YOUR_DATA_SOURCE_ID>
```

---

## Populating the RDS MySQL Database

To initialize the tables and seed data in your Amazon RDS MySQL instance:

```bash
# Connect to MySQL RDS via bastion or from within VPC (ECS backend container / EC2)
mysql -h <RDS_ENDPOINT> -u <USERNAME> -p db < src/sql-assets/01_schema_definitions.sql
mysql -h <RDS_ENDPOINT> -u <USERNAME> -p db < src/sql-assets/06_seed_sample_data.sql
```

