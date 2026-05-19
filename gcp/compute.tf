resource "null_resource" "compile_requirements" {
  triggers = {
    pyproject_md5 = filemd5("${path.module}/../pyproject.toml")
  }

  provisioner "local-exec" {
    command = "uv pip compile ${path.module}/../pyproject.toml -o ${path.module}/../app/upsert_index/requirements.txt && uv pip compile ${path.module}/../pyproject.toml -o ${path.module}/../app/search_index/requirements.txt"
  }
}

data "archive_file" "upsert-index-func-zip" {
  type        = "zip"
  source_dir  = "${path.module}/../app/upsert_index/"
  output_path = "${path.module}/../upsert-index.zip"

  depends_on = [null_resource.compile_requirements]
}

resource "google_storage_bucket_object" "upsert-index-zip" {
  name   = "upsert-index-${filemd5("${path.root}/../upsert-index.zip")}.zip"
  bucket = google_storage_bucket.cloud-func-source.name

  source = "${path.root}/../upsert-index.zip"
}

resource "google_cloudfunctions2_function" "upsert-index-func" {
  name        = "upsert-index-func-${random_string.deployment_suffix.result}"
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
    available_cpu = "1"
    available_memory   = "2Gi"
    timeout_seconds    = 60

    service_account_email = google_service_account.rag-cf-sa.email

    environment_variables = {
        PROJECT_ID = var.PROJECT_ID
        REGION = var.REGION
        DOC_CHUNK_BUCKET = google_storage_bucket.document-chunks.name
        INDEX_ID = element(split("/", google_vertex_ai_index.rag-vector-store.id), 5)
        ENDPOINT_ID = element(split("/", google_vertex_ai_index_endpoint.rag-index-endpoint.id), 5)
        OPENAI_API_KEY = var.OPENAI_API_KEY
        CHUNKING_STRATEGY = "semantic"
    }
    ingress_settings = "ALLOW_ALL"
  }

  event_trigger {
    trigger_region = var.REGION
    event_type     = "google.cloud.storage.object.v1.finalized"
    retry_policy   = "RETRY_POLICY_RETRY"

    event_filters {
      attribute = "bucket"
      value = google_storage_bucket.document-input.name
    }
  }
}

data "archive_file" "search-index-func-zip" {
  type        = "zip"
  source_dir  = "${path.module}/../app/search_index/"
  output_path = "${path.module}/../search-index.zip"

  depends_on = [null_resource.compile_requirements]
}

resource "google_storage_bucket_object" "search-index-zip" {
  name   = "search-index-${filemd5("${path.root}/../search-index.zip")}-.zip"
  bucket = google_storage_bucket.cloud-func-source.name

  source = "${path.root}/../search-index.zip"
}


resource "google_cloudfunctions2_function" "search-index-func" {
  name        = "search-index-func-${random_string.deployment_suffix.result}"
  location    = var.REGION
  project     = var.PROJECT_ID
  description = "Search vector search index"

  build_config {
    runtime     = "python312"
    entry_point = "search_index"

    source {
      storage_source {
        bucket = google_storage_bucket.cloud-func-source.name
        object = google_storage_bucket_object.search-index-zip.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    available_memory   = "2Gi"
    available_cpu = "1"
    timeout_seconds    = 60

    service_account_email = google_service_account.rag-cf-sa.email

    environment_variables = {
        PROJECT_ID = var.PROJECT_ID
        REGION = var.REGION
        DOC_CHUNK_BUCKET = google_storage_bucket.document-chunks.name
        INDEX_ID = element(split("/", google_vertex_ai_index.rag-vector-store.id), 5)
        ENDPOINT_ID = element(split("/", google_vertex_ai_index_endpoint.rag-index-endpoint.id), 5)
        OPENAI_API_KEY = var.OPENAI_API_KEY
        CHUNKING_STRATEGY = "semantic"
    }
    ingress_settings = "ALLOW_ALL"
  }
}
