"""AWS Lambda handler for FastAPI application."""
import os
from mangum import Mangum

# Create /tmp directories
os.makedirs("/tmp/uploads", exist_ok=True)
os.makedirs("/tmp/cached_chunks", exist_ok=True)

# Import app after directory creation
from app.main import app

# Lambda handler
handler = Mangum(app, lifespan="off")
