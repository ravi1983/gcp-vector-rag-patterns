
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
  
  
  metadata {
    config {
      dimensions                  = 768
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

resource "google_vertex_ai_index_endpoint_deployed_index" "rag-index-deployment" {
  deployed_index_id     = "rag_index_deployment"
  display_name          = "RAG Index Deployment"
  region                = var.REGION
  index                 = google_vertex_ai_index.rag-vector-store.id
  index_endpoint        = google_vertex_ai_index_endpoint.rag-index-endpoint.id
  enable_access_logging = false
}