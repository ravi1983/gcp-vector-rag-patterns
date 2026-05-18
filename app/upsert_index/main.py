import hashlib

import functions_framework
import os
import tempfile

from google.cloud import storage
from langchain_openai import OpenAIEmbeddings
from langchain_google_vertexai import VectorSearchVectorStore
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader

# Initialize Global GCP Clients
storage_client = storage.Client(project=os.environ["PROJECT_ID"])

# Embedding model and vector search init
_chunking_strategy = os.environ.get("CHUNKING_STRATEGY", "recursive")

_embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
_vector_store = VectorSearchVectorStore.from_components(
    project_id=os.environ.get("PROJECT_ID"),
    region=os.environ.get("REGION", "us-central1"),
    gcs_bucket_name=os.environ.get("DOC_CHUNK_BUCKET"),
    index_id=os.environ.get("INDEX_ID"),
    endpoint_id=os.environ.get("ENDPOINT_ID"),
    chunking_strategy=_chunking_strategy,
    embedding=_embeddings,
    stream_update=True,
)


@functions_framework.cloud_event
def upsert_index(cloud_event):
    data = cloud_event.data
    bucket_name = data["bucket"]
    file_name = data["name"]

    if not file_name.lower().endswith(".pdf"):
        return

    print(f"Processing {file_name} using OpenAI Embeddings...")

    # Download PDF from GCS to local volatile memory space
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as temp_pdf:
        blob.download_to_filename(temp_pdf.name)
        temp_pdf_path = temp_pdf.name

    try:
        # Document Parsing and Splitting Logic
        loader = PyPDFLoader(temp_pdf_path, mode="page")
        docs = loader.load()

        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000, chunk_overlap=30
        )
        chunks = text_splitter.split_documents(docs)

        # # Ingestion tracking labels for your Chunking Lab metrics
        # strategy = "recursive"
        # if "semantic" in file_name:
        #     strategy = "semantic"

        chunk_ids = []
        file_hash = hashlib.md5(file_name.encode("utf-8")).hexdigest()
        for index, chunk in enumerate(chunks):
            chunk_id = f"{file_hash}_${_chunking_strategy}_{index}"
            chunk_ids.append(hashlib.md5(chunk_id.encode("utf-8")).hexdigest())

            chunk.metadata["chunking_strategy"] = _chunking_strategy
            chunk.metadata["source"] = file_name

        # 3. Upsert execution block
        print(f"Streaming {len(chunks)} OpenAI vectors to Vertex AI Index...")
        _vector_store.add_documents(chunks, ids=chunk_ids)
        print("Upsert successful.")

    finally:
        if os.path.exists(temp_pdf_path):
            os.remove(temp_pdf_path)
