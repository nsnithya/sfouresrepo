# Load the libraries
from llama_index import (set_global_service_context,
                         VectorStoreIndex,
                         Document)

from utils.index_utils import (load_aws_llm_embedding_from_bedrock,
                                           set_service_context,
                                           load_documents,
                                           create_case_folders_for_vectors,
                                           build_sentence_window_index,
                                           build_automerging_index)
from utils.load_config import LoadConfig
CFG = LoadConfig()
import os
from pyprojroot import here

def create_basic_index(case_doc):
    """Read a document, create a Basic RAG index, and save it."""
    # Extract the file path from the case document
    file_path = case_doc.extra_info.get('file_path')
    print(f"Now Processing ..: {file_path}")
    file_name_no_ext = os.path.splitext(os.path.basename(file_path))[0]  # Get the file name without extension
    folder_path = os.path.join(CFG.index_dir, file_name_no_ext, "basic_index")
    if not os.path.exists(folder_path):
        print(f"Saving basic index for file: {file_path} --> {folder_path}")
        # Read the content of the file
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()
        # Create a Document object
        document = Document(text=content)
        # Prepare Basic index
        index = VectorStoreIndex.from_documents([document])
        # Save the index
        index.storage_context.persist(here(folder_path))
    else:
        print(f"Index already exists for file: {file_path} at --> {folder_path}")

def create_pagewise_index(case_doc):
    """Create and save the Page-wise RAG index."""
    print("Processing the documents and creating the index for Page-wise RAG...")
    # Extract the file path from the case document
    file_path = case_doc.extra_info.get('file_path')
    #print(f"Now Processing ..: {file_path}")
    file_name_no_ext = os.path.splitext(os.path.basename(file_path))[0]  # Get the file name without extension
    folder_path = os.path.join(CFG.index_dir, file_name_no_ext, "pagewise_index")
    if not os.path.exists(folder_path):
        print(f"Saving pagewise index for file: {file_path} --> {folder_path}")
        # Read the content of the file
        with open(file_path, 'r', encoding='utf-8') as file:
            content = file.read()
        # Create a Document object
        document = Document(text=content)
        # Prepare Basic index
        index = VectorStoreIndex.from_documents([document])
        # Save the index
        index.storage_context.persist(folder_path)
        print(f"Index of Page-wise RAG is saved in {folder_path}.\n")
    else:
        print(f"Page wise index already exists for file: {file_path} at --> {folder_path}")

def create_sentence_retrieval_index(merged_document, llm, embed_model, save_dir, window_size):
    """Create and save the Sentence Retrieval index."""
    print("Processing the documents and creating the index for Sentence Retrieval...")
    sentence_index = build_sentence_window_index(
        merged_document,
        llm,
        embed_model=embed_model,
        save_dir=save_dir,
        window_size=window_size
    )
    print(f"Index of Sentence Retrieval is saved in {save_dir}.\n")

def create_automerging_retrieval_index(page_separated_documents, llm, embed_model, save_dir, chunk_sizes):
    """Create and save the Auto-merging Retrieval index."""
    print("Processing the documents and creating the index for Auto-merging Retrieval...")
    automerging_index = build_automerging_index(
        page_separated_documents,
        llm,
        embed_model=embed_model,
        save_dir=save_dir,
        chunk_sizes=chunk_sizes
    )
    print(f"Index of Auto-merging Retrieval is saved in {save_dir}.")

def prep_llama_indexes():
# Load LLM and embedding model
   # llm, embed_model = load_aws_llm_and_embedding_models(
    llm, embed_model = load_aws_llm_embedding_from_bedrock(
        gpt_model=CFG.gpt_model, embed_model_name=CFG.embed_model_name)
    # Set the service context
    service_context = set_service_context(
        llm=llm,
        embed_model=embed_model,
    )
    set_global_service_context(service_context)
    create_case_folders_for_vectors(CFG.index_dir,CFG.documents_dir)
    # Load the documents
    page_separated_documents = load_documents(
        CFG.documents_dir)
    for case_doc in page_separated_documents:
        #create_basic_index(case_doc)
        create_pagewise_index(case_doc)
        create_sentence_retrieval_index(case_doc,llm,embed_model,here(CFG.sentence_index_save_dir),CFG.sentence_window_size)
        create_automerging_retrieval_index([case_doc],llm,embed_model,here(CFG.auto_merging_retrieval_index_save_dir),CFG.chunk_sizes)

print(F"Process all document and create vectors")

if __name__ == "__main__":
    prep_llama_indexes()
