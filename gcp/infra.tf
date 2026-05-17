
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


# resource "google_vertex_ai_index_endpoint" "chunking_lab_endpoint" {
#   display_name = "chunking-lab-endpoint"
#   description  = "Public endpoint to query the chunking lab vector store"
  
#   public_endpoint_enabled = true
# }

# resource "google_vertex_ai_index_deployment" "index_deployment" {
#   index_endpoint = google_vertex_ai_index_endpoint.chunking_lab_endpoint.id
#   index          = google_vertex_ai_index.chunking_lab_index.id
#   deployed_index_id = "deployed_chunking_lab_index"

#   automatic_resources {
#     min_replica_count = 1
#     max_replica_count = 2
#   }
# }