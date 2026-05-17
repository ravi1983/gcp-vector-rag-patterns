import functions_framework
import os

from flask import jsonify
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_google_vertexai import VectorSearchVectorStore
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough
from langchain_core.output_parsers import StrOutputParser

# Define embedding and system prompt
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

_rag_prompt = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            """You are an expert technical assistant. Use ONLY the following context
    to answer the questions. If answer is not found in context, you cannot answer the question.
         
    Context: {context}""",
        ),
        ("user", "{input}"),
    ]
)

# Define model and vector store retriever
_search_kwargs = {"k": 3}
_search_kwargs["filter"] = {"chunking_strategy": _chunking_strategy}
statistics_retriever = _vector_store.as_retriever(search_kwargs=_search_kwargs)

_model = ChatOpenAI(model="gpt-4.1", temperature=0)


def _format_docs(docs):
    return "\n".join(doc.page_content for doc in docs)


# Cloud function
@functions_framework.http
def search_index(request):
    if request.method == "OPTIONS":
        headers = {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "3600",
        }
        return ("", 204, headers)

    if request.method != "POST":
        return jsonify({"error": "Method not allowed. Use POST."}), 405

    request_json = request.get_json(silent=True)
    if not request_json or "query" not in request_json:
        return jsonify({"error": "Missing required field: 'query'"}), 400

    user_query = request_json["query"]

    try:
        statistics_rag_chain = (
            {
                "context": statistics_retriever | _format_docs,
                "input": RunnablePassthrough(),
            }
            | _rag_prompt
            | _model
            | StrOutputParser()
        )

        print(
            f"Executing RAG Chain query: '{user_query}' with strategy: '{_chunking_strategy}'"
        )
        ai_response = statistics_rag_chain.invoke(user_query)

        # Send structured output payload back to requester
        response_data = {
            "query": user_query,
            "chunking_strategy": _chunking_strategy,
            "answer": ai_response,
        }

        headers = {"Access-Control-Allow-Origin": "*"}
        return (jsonify(response_data), 200, headers)

    except Exception as e:
        print(f"Internal RAG pipeline error occurred: {str(e)}")
        return (
            jsonify({"error": "Internal execution failure processing vector query."}),
            500,
        )
