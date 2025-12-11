# Multi-Source RAG + Text-to-SQL System

A production-ready FastAPI application that combines **Document RAG (Retrieval-Augmented Generation)** with **Text-to-SQL** capabilities, featuring intelligent query routing, evaluation metrics, and monitoring.

## 🌟 Features

- **📄 Document RAG**: Upload and query documents (PDF, DOCX, CSV, JSON, TXT) using AI-powered retrieval
- **🗄️ Text-to-SQL**: Convert natural language questions to SQL queries with approval workflow
- **🧭 Intelligent Query Routing**: Automatically routes queries to SQL, Documents, or both (HYBRID)
- **📊 Evaluation & Monitoring**: RAGAS metrics (faithfulness, relevancy) and OPIK tracking
- **✅ Input Validation**: Comprehensive validation for file uploads and queries
- **🛡️ Error Handling**: Structured error responses with detailed messages
- **📈 Production-Ready**: Full logging, monitoring, and graceful degradation

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [API Endpoints](#api-endpoints)
- [Query Routing](#query-routing)
- [Evaluation](#evaluation)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

## 🚀 Quick Start

```bash
# 1. Clone the repository
cd multidata-rag-project

# 2. Create virtual environment (Python 3.12+)
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt
# OR using UV (faster):
uv pip install -r requirements.txt

# 4. Configure environment variables
cp .env.example .env
# Edit .env with your API keys (see Configuration section)

# 5. Run the application
uvicorn app.main:app --reload

# 6. Visit the API docs
open http://localhost:8000/docs
```

## 📦 Prerequisites

### Required

- **Python 3.12+**
- **OpenAI API Key** (for embeddings and LLM)
- **Pinecone Account** (for vector storage)
  - Create an index with dimension=1536, metric=cosine
- **PostgreSQL Database** (for Text-to-SQL)
  - Supabase recommended for easy setup

### Optional

- **OPIK API Key** (for monitoring, can run locally without key)

## 🔧 Installation

### 1. System Dependencies

**macOS:**
```bash
brew install libmagic poppler tesseract
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y libmagic1 poppler-utils tesseract-ocr
```

**Windows:**
- Download and install [Poppler](https://github.com/oschwartz10612/poppler-windows/releases)
- Download and install [Tesseract](https://github.com/UB-Mannheim/tesseract/wiki)

### 2. Python Packages

```bash
# Using pip
pip install -r requirements.txt

# Using UV (faster, recommended)
uv pip install -r requirements.txt
```

### 3. External Services Setup

#### Pinecone (Vector Database)

1. Sign up at [pinecone.io](https://www.pinecone.io)
2. Create a new index:
   - **Dimensions**: 1536 (for OpenAI text-embedding-3-small)
   - **Metric**: cosine
   - **Region**: us-east-1-aws (or your preferred region)
3. Get your API key from the dashboard

#### Supabase (PostgreSQL Database)

1. Sign up at [supabase.com](https://supabase.com)
2. Create a new project
3. Run the schema from `data/sql/schema.sql` in the SQL editor
4. Optionally, generate sample data:
   ```bash
   python data/generate_sample_data.py
   ```
5. Get your connection string from Project Settings → Database

#### OPIK (Monitoring - Optional)

1. Sign up at [opik.ai](https://www.opik.ai) or run locally
2. Get your API key (optional, works without key in local mode)

## ⚙️ Configuration

Create a `.env` file in the project root:

```env
# OpenAI Configuration
OPENAI_API_KEY=sk-...

# Pinecone Configuration
PINECONE_API_KEY=pcsk_...
PINECONE_ENVIRONMENT=us-east-1-aws
PINECONE_INDEX_NAME=rag-documents

# Supabase/PostgreSQL Configuration
DATABASE_URL=postgresql://user:password@host:port/database

# OPIK Monitoring (Optional)
OPIK_API_KEY=  # Leave empty for local tracking

# Text Chunking Configuration
CHUNK_SIZE=512
CHUNK_OVERLAP=50
```

## 📖 Usage

### 1. Start the Server

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Upload a Document

```bash
curl -X POST "http://localhost:8000/upload" \
  -F "file=@document.pdf"
```

**Response:**
```json
{
  "status": "success",
  "filename": "document.pdf",
  "file_size": "2.5 MB",
  "chunks_created": 15,
  "total_tokens": 7680,
  "message": "Document processed and 15 chunks stored in Pinecone"
}
```

### 3. Query Documents

```bash
curl -X POST "http://localhost:8000/query/documents" \
  -H "Content-Type: application/json" \
  -d '{"question": "What is the return policy?", "top_k": 3}'
```

### 4. Generate SQL

```bash
curl -X POST "http://localhost:8000/query/sql/generate" \
  -H "Content-Type: application/json" \
  -d '{"question": "How many customers do we have?"}'
```

### 5. Unified Query (Recommended)

```bash
# Automatically routes to the appropriate service
curl -X POST "http://localhost:8000/query" \
  -H "Content-Type: application/json" \
  -d '{"question": "Show total revenue and explain our pricing strategy"}'
```

## 🔌 API Endpoints

### Health & Info

- **GET `/health`** - Health check
- **GET `/info`** - System information and available features
- **GET `/`** - Welcome message with quick links

### Document Operations

- **POST `/upload`** - Upload and process documents
  - Supported formats: PDF, DOCX, DOC, CSV, JSON, TXT
  - Max size: 50 MB
  - Returns: chunks created, token count

- **GET `/documents`** - List all uploaded documents
  - Returns: filename, size, upload timestamp

- **POST `/query/documents`** - Query documents using RAG
  - Parameters: `question` (string), `top_k` (int, default=3)
  - Returns: answer, sources, chunks used

### SQL Operations

- **POST `/query/sql/generate`** - Generate SQL from natural language
  - Parameters: `question` (string)
  - Returns: `query_id`, SQL, explanation

- **POST `/query/sql/execute`** - Execute approved SQL query
  - Parameters: `query_id` (string), `approved` (bool)
  - Returns: results, row count

- **GET `/query/sql/pending`** - List pending SQL queries
  - Returns: all queries awaiting approval

### Unified Query (Recommended)

- **POST `/query`** - Intelligent query routing
  - Parameters:
    - `question` (string, required)
    - `auto_approve_sql` (bool, default=false, testing only)
    - `top_k` (int, default=3)
  - Returns: routed response with explanation

## 🧭 Query Routing

The system automatically routes queries based on keyword analysis:

### SQL Queries
Routed to Text-to-SQL service for data retrieval:

**Keywords**: count, total, sum, average, revenue, sales, orders, customers, list all, show all, how many, top, bottom, last, recent, etc.

**Examples:**
- "How many customers do we have?"
- "What is the total revenue from delivered orders?"
- "Show me the top 10 customers by spending"

### Document Queries
Routed to RAG service for information retrieval:

**Keywords**: what is, explain, define, policy, procedure, guide, manual, how to, why, according to, etc.

**Examples:**
- "What is our return policy?"
- "Explain the customer complaint procedure"
- "How should I process a refund?"

### Hybrid Queries
Routed to both services, combining data with context:

**Keywords**: and explain, and describe, show data and explain, etc.

**Examples:**
- "Show total revenue by segment and explain our segmentation strategy"
- "List top products and describe pricing policies"

## 📊 Evaluation

Run the RAGAS evaluation to measure system quality:

```bash
python evaluate.py
```

**Metrics:**
- **Faithfulness** (target > 0.7): Answer accuracy based on retrieved context
- **Answer Relevancy** (target > 0.8): How well the answer matches the question

**Output:**
- Console: Real-time progress and scores
- File: `evaluation_results.json` with detailed results

## 🏗️ Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       v
┌──────────────────────────────────────┐
│       FastAPI Application            │
│  (main.py with OPIK monitoring)     │
└──────┬───────────────────────────────┘
       │
       v
┌──────────────────┐
│  Query Router    │ ← Keyword-based routing
└──────┬───────────┘
       │
       ├─────────────┬─────────────────┐
       │             │                 │
       v             v                 v
   [SQL Path]   [Documents]       [HYBRID]
       │             │                 │
       v             v                 │
┌──────────┐  ┌──────────┐           │
│  Vanna   │  │   RAG    │           │
│ SQL Gen  │  │ Pipeline │           │
└────┬─────┘  └────┬─────┘           │
     │             │                  │
     v             v                  v
┌──────────┐  ┌──────────┐     ┌──────────┐
│PostgreSQL│  │ Pinecone │     │   Both   │
└──────────┘  └──────────┘     └──────────┘
```

### Components

- **Document Service**: Parses PDF/DOCX/CSV/JSON using Unstructured.io
- **Embedding Service**: OpenAI text-embedding-3-small (1536 dimensions)
- **Vector Service**: Pinecone with gRPC for fast vector operations
- **RAG Service**: Retrieval + GPT-4 generation with source citations
- **SQL Service**: Vanna.ai for Text-to-SQL with training on schema
- **Query Router**: Keyword-based intelligent routing
- **Validation**: File type/size, query length, SQL safety checks
- **Monitoring**: OPIK tracking on all key endpoints

## 🐛 Troubleshooting

### Common Issues

#### 1. Services Not Initialized

**Error**: `503 Service Unavailable`

**Solution**:
- Check `.env` file has correct API keys
- Verify Pinecone index exists with dimension=1536
- Test database connection string

```bash
# Test Pinecone connection
python -c "from pinecone import Pinecone; pc = Pinecone(api_key='YOUR_KEY'); print(pc.list_indexes())"

# Test database connection
python -c "import sqlalchemy; engine = sqlalchemy.create_engine('YOUR_DB_URL'); print(engine.connect())"
```

#### 2. File Upload Fails

**Error**: `400 Validation Error - Invalid file type`

**Solution**:
- Ensure file is PDF, DOCX, CSV, JSON, or TXT
- Check file size is under 50 MB
- Verify system dependencies installed (libmagic, poppler)

#### 3. RAGAS Evaluation Fails

**Error**: `No valid results to evaluate`

**Solution**:
- Ensure API keys are configured
- Upload at least one document for document queries
- Run database schema setup for SQL queries
- Check `evaluation_results.json` for detailed errors

#### 4. Import Errors

**Error**: `ModuleNotFoundError: No module named 'opik'`

**Solution**:
```bash
# Reinstall dependencies
pip install -r requirements.txt

# Verify installation
pip list | grep opik
```

## 👨‍💻 Development

### Project Structure

```
multidata-rag-project/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app with endpoints
│   ├── config.py            # Pydantic settings
│   ├── utils.py             # Validation and error handling
│   └── services/
│       ├── document_service.py   # Document parsing & chunking
│       ├── embedding_service.py  # OpenAI embeddings
│       ├── vector_service.py     # Pinecone operations
│       ├── rag_service.py        # RAG pipeline
│       ├── sql_service.py        # Vanna Text-to-SQL
│       └── router_service.py     # Query routing
├── data/
│   ├── uploads/             # Uploaded documents (gitignored)
│   ├── sql/
│   │   └── schema.sql       # Database schema
│   └── generate_sample_data.py  # Sample data generator
├── tests/
│   └── test_queries.json    # Evaluation test queries
├── evaluate.py              # RAGAS evaluation script
├── requirements.txt         # Python dependencies
├── .env.example            # Environment template
├── .gitignore              # Git ignore rules
└── README.md               # This file
```

### Running Tests

```bash
# Run evaluation
python evaluate.py

# Test individual endpoints
curl http://localhost:8000/health
curl http://localhost:8000/info
```

### Code Style

- **Type hints**: All functions have type annotations
- **Docstrings**: Google-style docstrings for all public functions
- **Validation**: Input validation on all endpoints
- **Error handling**: Structured error responses

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For issues and questions:

- Create an issue in the GitHub repository
- Check the Troubleshooting section above
- Review the API documentation at `/docs`

## 🎯 Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Document Upload | All formats work | Test with PDF, DOCX, CSV, JSON |
| Document Retrieval | Top-3 relevant chunks | Manual review of query results |
| SQL Generation | 70%+ accuracy | Run evaluate.py |
| Query Routing | 80%+ correct | Test with mixed queries |
| RAGAS Faithfulness | > 0.7 | Run evaluate.py |
| RAGAS Relevancy | > 0.8 | Run evaluate.py |
| Response Time | < 15 seconds | Monitor OPIK dashboard |

## 🚀 Deployment

### Docker Deployment

The application is fully containerized and ready for Docker deployment.

#### Quick Start with Docker Compose (Recommended)

```bash
# 1. Ensure .env file is configured
cp .env.example .env
# Edit .env with your API keys

# 2. Build and start the container
docker-compose up -d

# 3. View logs
docker-compose logs -f

# 4. Stop the container
docker-compose down
```

#### Manual Docker Build

```bash
# Build the image
docker build -t rag-text-to-sql:latest .

# Run the container
docker run -d \
  --name rag-text-to-sql \
  -p 8000:8000 \
  -v $(pwd)/data/uploads:/app/data/uploads \
  -v $(pwd)/data/vanna_chromadb:/app/data/vanna_chromadb \
  --env-file .env \
  rag-text-to-sql:latest

# View logs
docker logs -f rag-text-to-sql

# Stop and remove
docker stop rag-text-to-sql
docker rm rag-text-to-sql
```

#### Docker Features

- **Multi-stage build**: Optimized image size (~800 MB)
- **Health checks**: Automatic health monitoring
- **Persistent volumes**: Documents and training data preserved
- **System dependencies**: All required packages pre-installed
- **Production-ready**: Runs with uvicorn, proper signal handling

#### Environment Variables in Docker

All environment variables from `.env` are automatically loaded. Required variables:

```env
OPENAI_API_KEY=sk-...
PINECONE_API_KEY=pcsk_...
PINECONE_INDEX_NAME=rag-documents
DATABASE_URL=postgresql://...
```

#### Docker Troubleshooting

**Container fails to start:**
```bash
# Check logs
docker logs rag-text-to-sql

# Verify .env file exists
ls -la .env

# Check port availability
lsof -i :8000
```

**Services not initialized:**
- Verify API keys in `.env`
- Check Pinecone index exists
- Test database connection outside Docker first

**Health check fails:**
```bash
# Check health endpoint manually
docker exec rag-text-to-sql curl http://localhost:8000/health
```

### Cloud Deployment

Recommended platforms:
- **Railway** - Easy deployment with PostgreSQL
- **Render** - Free tier available
- **Fly.io** - Global edge deployment
- **AWS EC2** - Full control, requires more setup

## 📚 Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com)
- [Pinecone Documentation](https://docs.pinecone.io)
- [Vanna.ai Documentation](https://vanna.ai/docs)
- [RAGAS Documentation](https://docs.ragas.io)
- [OPIK Documentation](https://www.opik.ai/docs)

---

**Built with ❤️ using FastAPI, OpenAI, Pinecone, and Vanna.ai**
