from pyprojroot import here
from llama_index.llms.ollama import Ollama
from llama_index.node_parser import SentenceWindowNodeParser
from llama_index import (load_index_from_storage,
                         ServiceContext,
                         StorageContext,
                         SimpleDirectoryReader,
                         VectorStoreIndex,
                         )
from llama_index.retrievers import AutoMergingRetriever
from llama_index.query_engine import RetrieverQueryEngine
from llama_index.indices.postprocessor import (SentenceTransformerRerank,
                                               MetadataReplacementPostProcessor)
from llama_index.node_parser import get_leaf_nodes, HierarchicalNodeParser
import os
from pathlib import Path
from dotenv import load_dotenv, find_dotenv
_ = load_dotenv(find_dotenv())
#from llama_index.core.settings import Settings
from llama_index.llms.bedrock import Bedrock
from llama_index.embeddings.bedrock import BedrockEmbedding, Models
import boto3
from utils.load_config import LoadConfig
CFG = LoadConfig()

def load_aws_llm_embedding_from_bedrock(gpt_model: str = "anthropic.claude-v2", embed_model_name: str = "amazon.titan-embed-text-v1"):
    # Load the  model and the embedding model from AWS Bedrock
    boto3_bedrock = boto3.client('bedrock-runtime')
    llm = Bedrock(model=gpt_model,temperature=0.1,max_tokens=4096)
    #llm=Ollama(model=gpt_model,temperature=0.1,max_tokens=512,request_timeout=)
    print(f"Current GPT model used:{gpt_model}")
    print(f"Current embedding model used:{embed_model_name}")
    if embed_model_name == "amazon.titan-embed-text-v1":
        embed_model = BedrockEmbedding(client=boto3_bedrock,model_name="amazon.titan-embed-text-v1")
    elif embed_model_name == "bge-small-en-v1.5":
        embed_model = "local:BAAI/bge-small-en-v1.5"
    return llm, embed_model

def set_service_context(llm, embed_model):
    service_context = ServiceContext.from_defaults(
        llm=llm,
        embed_model=embed_model,
    )
    return service_context

def load_documents(documents_dir):
    documents_path = Path(documents_dir)
    print(f"IU:Source Document path:{documents_path}")
    if not documents_path.is_dir():
        raise FileNotFoundError(f"The directory {documents_dir} does not exist.")
    
    input_files = [str(documents_path / d) for d in os.listdir(documents_path) if documents_path.joinpath(d).is_file()]

    documents = SimpleDirectoryReader(input_files=input_files).load_data()
    print(f"IU:Document file path:{documents[0]}")
    return documents

def create_case_folders_for_vectors(indexes_dir,pfd_files_location):
    # Define the path for the Indexes directory
    indexes_dir = Path(indexes_dir)
    print(f"IU:location for index:{indexes_dir}")
    # Create the Indexes directory if it doesn't exist
    indexes_dir.mkdir(parents=True, exist_ok=True)
    pdf_dir = Path(pfd_files_location)
    # Iterate over each file in the documents directory
    for file in os.listdir(pdf_dir):
        file_path = Path(pdf_dir) / file
        
        if file_path.is_file():
            # Create a folder named after the file (without the extension)
            folder_name = file_path.stem  # Get the file name without extension
            folder_path = indexes_dir / folder_name
            folder_path.mkdir(exist_ok=True)  # Create the folder



def build_sentence_window_index(document, llm, save_dir, embed_model="local:BAAI/bge-small-en-v1.5", window_size: int = 3):
    
    # Extract the file path from the case document and set dynamic save location
    file_path = document.extra_info.get('file_path')
    print(f"IU:build_sentence_windows_index:The File in documents list: {file_path}")
    file_name_no_ext = os.path.splitext(os.path.basename(file_path))[0]  # Get the file name without extension
    save_dir = os.path.join(CFG.index_dir, file_name_no_ext, "sentence_windows_index")
    print(f"Saving sentence_windows_index index for file: {file_path} --> {save_dir}")
    # create the sentence window node parser w/ default settings
    node_parser = SentenceWindowNodeParser.from_defaults(
        window_size=window_size,
        window_metadata_key="window",
        original_text_metadata_key="original_text",
    )
    sentence_context = ServiceContext.from_defaults(
        llm=llm,
        embed_model=embed_model,
        node_parser=node_parser,
    )
    if not os.path.exists(save_dir):
        sentence_index = VectorStoreIndex.from_documents(
            [document], service_context=sentence_context
        )
        sentence_index.storage_context.persist(persist_dir=save_dir)
    else:
        sentence_index = load_index_from_storage(
            StorageContext.from_defaults(persist_dir=save_dir),
            service_context=sentence_context,
        )

    return sentence_index


def build_automerging_index(
    documents,
    llm,
    save_dir,
    embed_model="local:BAAI/bge-small-en-v1.5",
    chunk_sizes=None,
):
    chunk_sizes = chunk_sizes or [2048, 512, 128]
    node_parser = HierarchicalNodeParser.from_defaults(chunk_sizes=chunk_sizes)
    nodes = node_parser.get_nodes_from_documents(documents)
    leaf_nodes = get_leaf_nodes(nodes)
    merging_context = ServiceContext.from_defaults(
        llm=llm,
        embed_model=embed_model,
    )
    storage_context = StorageContext.from_defaults()
    storage_context.docstore.add_documents(nodes)

    # Extract the file path from the case document and set dynamic save location
    file_path = documents[0].extra_info.get('file_path')
    print(f"IU:build_sentence_windows_index:The File in documents list: {file_path}")
    file_name_no_ext = os.path.splitext(os.path.basename(file_path))[0]  # Get the file name without extension
    save_dir = os.path.join(CFG.index_dir, file_name_no_ext, "automerging_index")
    print(f"Saving build_automerging_index for file: {file_path} --> {save_dir}")

    if not os.path.exists(save_dir):
        automerging_index = VectorStoreIndex(
            leaf_nodes, storage_context=storage_context, service_context=merging_context
        )
        automerging_index.storage_context.persist(persist_dir=save_dir)
    else:
        automerging_index = load_index_from_storage(
            StorageContext.from_defaults(persist_dir=save_dir),
            service_context=merging_context,
        )
    return automerging_index


def get_sentence_window_query_engine(
    sentence_index,
    rerank_model: str = "BAAI/bge-reranker-base",
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
    similarity_top_k: int = 12,
    rerank_top_n: int = 2,
):
    base_retriever = automerging_index.as_retriever(
        similarity_top_k=similarity_top_k)
    retriever = AutoMergingRetriever(
        base_retriever, automerging_index.storage_context, verbose=True
    )
    rerank = SentenceTransformerRerank(
        top_n=rerank_top_n, model="BAAI/bge-reranker-base"
    )
    auto_merging_engine = RetrieverQueryEngine.from_args(
        retriever, node_postprocessors=[rerank]
    )
    return auto_merging_engine
