resource "google_storage_bucket" "cloud-func-source" {
  name                        = "cloud-func-source-987q2"
  location                    = var.REGION
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "document-chunks" {
  name                        = "document-chunks-987q2"
  location                    = var.REGION
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "document-input" {
  name                        = "document-input-987q2"
  location                    = var.REGION
  storage_class               = "STANDARD"
  force_destroy               = true
  uniform_bucket_level_access = true
}

resource "google_vertex_ai_index" "rag-vector-store" {
  display_name = "rag-vector-store"
  description  = "Vector index to showcase dfifferent chunking strategies"
  index_update_method = "STREAM_UPDATE"
  
  metadata {
    config {
      dimensions                  = 1536
      distance_measure_type       = "DOT_PRODUCT_DISTANCE"
      feature_norm_type           = "UNIT_L2_NORM"
      shard_size                  = "SHARD_SIZE_SMALL"
      algorithm_config {
        brute_force_config { }
      }
    }
  }
}


resource "google_vertex_ai_index_endpoint" "rag-index-endpoint" {
  display_name = "rag-index-endpoint"  
  public_endpoint_enabled = true
}

resource "random_string" "deployment_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_vertex_ai_index_endpoint_deployed_index" "rag-index-deployment" {
  deployed_index_id     = "rag_index_deployment_${random_string.deployment_suffix.result}"
  display_name          = "RAG Index Deployment"
  region                = var.REGION
  index                 = google_vertex_ai_index.rag-vector-store.id
  index_endpoint        = google_vertex_ai_index_endpoint.rag-index-endpoint.id
  enable_access_logging = false
}

output "rag-index-id" {
  description = "RAG Index ID"
  value       = element(split("/", google_vertex_ai_index.rag-vector-store.id), 5)
}

output "rag-endpoint-id" {
  description = "RAG Endpoint ID"
  value       = element(split("/", google_vertex_ai_index_endpoint.rag-index-endpoint.id), 5)
}

output "rag-index-deployment-id" {
  description = "RAG Endpoint Deployment ID"
  value       = google_vertex_ai_index_endpoint_deployed_index.rag-index-deployment.deployed_index_id
}