from llama_index.indices.postprocessor import (SentenceTransformerRerank,
                                               MetadataReplacementPostProcessor)
from llama_index.query_engine import RetrieverQueryEngine
from llama_index.retrievers import AutoMergingRetriever
from llama_index.llms.bedrock import Bedrock
from llama_index.embeddings.bedrock import BedrockEmbedding, Models
import boto3

def load_aws_llm_embedding_from_bedrock(gpt_model: str = "anthropic.claude-v2", embed_model_name: str = "amazon.titan-embed-text-v1"):
    # Load the  model and the embedding model from AWS Bedrock
    boto3_bedrock = boto3.client('bedrock-runtime')
    llm = Bedrock(model=gpt_model,temperature=0.1,max_tokens=512,context_size=1024 )
    #,temperature=0.1,max_tokens=4096
   # llm=Ollama(model="llama3.2",request_timeout=600)
    print(f"modelname:{gpt_model}")
    print(f"embedding model:{embed_model_name}")
    if embed_model_name == "amazon.titan-embed-text-v1":
        embed_model = BedrockEmbedding(client=boto3_bedrock,model_name="amazon.titan-embed-text-v1")
    # elif embed_model_name == "bge-small-en-v1.5":
    #     embed_model = "local:BAAI/bge-small-en-v1.5"
    return llm, embed_model
def get_sentence_window_query_engine(
    sentence_index,
    rerank_model,
    similarity_top_k: int = 6,
    rerank_top_n: int = 2,
):

    # define postprocessors
    postproc = MetadataReplacementPostProcessor(target_metadata_key="window")
    rerank = SentenceTransformerRerank(
        top_n=rerank_top_n, model=rerank_model
    )

    sentence_window_engine = sentence_index.as_query_engine(
        similarity_top_k=similarity_top_k, node_postprocessors=[
            postproc, rerank]
    )
    return sentence_window_engine


def get_automerging_query_engine(
    automerging_index,
    rerank_model,
    similarity_top_k: int = 12,
    rerank_top_n: int = 2,
):
    base_retriever = automerging_index.as_retriever(
        similarity_top_k=similarity_top_k)
    retriever = AutoMergingRetriever(
        base_retriever, automerging_index.storage_context, verbose=True
    )
    rerank = SentenceTransformerRerank(
        top_n=rerank_top_n, model=rerank_model
    )
    auto_merging_engine = RetrieverQueryEngine.from_args(
        retriever, node_postprocessors=[rerank]
    )
    return auto_merging_engine
def get_pagewise_query_engine(
            pagewise_index,
            ):
            query_engine = pagewise_index.as_query_engine()
            return query_engine
            # # Format the prompt using the template
            # formatted_prompt = prompt_template.format(query=message.content)
            # print(f"Formatted Prompt:{formatted_prompt}")
            # response = query_engine.query(formatted_prompt)
            