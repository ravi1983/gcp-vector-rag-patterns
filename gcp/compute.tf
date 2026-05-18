resource "null_resource" "compile_requirements" {
  triggers = {
    pyproject_md5 = filemd5("${path.module}/../pyproject.toml")
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/../app/upsert_index && uv pip compile ../../pyproject.toml -o requirements.txt"
  }
}

data "archive_file" "upsert-index-func-zip" {
  type        = "zip"
  source_dir  = "${path.module}/../app/upsert_index/"
  output_path = "${path.module}/../upsert-index.zip"

  depends_on = [null_resource.compile_requirements]
}

resource "google_storage_bucket_object" "upsert-index-zip" {
  name   = "upsert-index.zip"
  bucket = google_storage_bucket.cloud-func-source.name

  source = "${path.root}/../upsert-index.zip"
}

resource "google_cloudfunctions2_function" "upsert-index" {
  name        = "upsert-index-func"
  location    = var.REGION
  project     = var.PROJECT_ID
  description = "Upsert vector search index"

  build_config {
    runtime     = "python312"
    entry_point = "upsert_index"

    source {
      storage_source {
        bucket = google_storage_bucket.cloud-func-source.name
        object = google_storage_bucket_object.upsert-index-zip.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    available_memory   = "512Mi"
    timeout_seconds    = 60

    environment_variables = {
        PROJECT_ID = var.PROJECT_ID
        REGION = var.REGION
        DOC_CHUNK_BUCKET = google_storage_bucket.document-chunks.name
        INDEX_ID = element(split("/", google_vertex_ai_index.rag-vector-store.id), 5)
        ENDPOINT_ID = element(split("/", google_vertex_ai_index_endpoint.rag-index-endpoint.id), 5)
        OPENAI_API_KEY = var.OPENAI_API_KEY
        CHUNKING_STRATEGY = "recursive"
    }
    ingress_settings = "ALLOW_ALL"
  }
}

# resource "google_storage_bucket_object" "search-index-zip" {
#   name   = "search-index-zip"
#   bucket = google_storage_bucket.cloud-func-source.name

#   source = "${path.root}/search-index.zip"
# }

# resource "google_cloudfunctions2_function" "search-index" {
#   name        = "search-index"
#   location    = var.REGION
#   project     = var.PROJECT_ID
#   description = "Search vector search index"

#   build_config {
#     runtime     = "python312"
#     entry_point = "search_index"

#     source {
#       storage_source {
#         bucket = google_storage_bucket.cloud-func-source.name
#         object = google_storage_bucket_object.search-index-zip.name
#       }
#     }
#   }

#   service_config {
#     max_instance_count = 10
#     available_memory   = "256Mi"
#     timeout_seconds    = 60

#     environment_variables = {
#         PROJECT_ID = var.PROJECT_ID
#         REGION = var.REGION
#         DOC_CHUNK_BUCKET = google_storage_bucket.document-chunks.name
#         INDEX_ID = google_vertex_ai_index_endpoint.rag-index-endpoint.id
#         ENDPOINT_ID = google_vertex_ai_index_endpoint_deployed_index.rag-index-deployment.id
#         OPENAI_API_KEY = var.OPENAI_API_KEY
#         CHUNKING_STRATEGY = "recursive"
#     }
#     ingress_settings = "ALLOW_ALL"
#   }
# }

