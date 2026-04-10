import os
import yaml
import time
import boto3
from pyprojroot import here
import pandas as pd
from llama_index.prompts import PromptTemplate
from llama_index import (load_index_from_storage,
                         set_global_service_context,
                         ServiceContext,
                         StorageContext,
                         )
from eval_utils import get_pagewise_query_engine, get_sentence_window_query_engine, get_automerging_query_engine,load_aws_llm_embedding_from_bedrock
from ratelimit import limits, sleep_and_retry
from dotenv import load_dotenv, find_dotenv
start_time = time.time()
_ = load_dotenv(find_dotenv())

with open(here("configs\config.yml")) as cfg:
    cfg = yaml.load(cfg, Loader=yaml.FullLoader)
#print(cfg["llm_cfg"])
llm, embed_model = load_aws_llm_embedding_from_bedrock(
        gpt_model=str(cfg["llm_cfg"]["gpt_model"]), embed_model_name=str(cfg["llm_cfg"]["embed_model_name"]))

# Set the service context
service_context = ServiceContext.from_defaults(
    llm=llm,
    embed_model=embed_model,
)
set_global_service_context(service_context)
# Create prompt template 
def create_prompt_template(template):
    """Define a simple prompt template with placeholders."""
    return PromptTemplate(
        template=template
    )
# Define rate limit: 5 calls per minute
CALLS = 4
PERIOD = 60  # seconds

llama_eval_method = cfg["llama_index_cfg"]["llama_eval_method"]

print(f"Questions will be processed using {llama_eval_method} method.")
print("----------------------------------------------------------\n\n")

def build_storage_context(persist_dir):
    """Create a storage context."""
    return StorageContext.from_defaults(persist_dir=here(persist_dir))

def load_index(storage_context):
    """Load index from storage context."""
    return load_index_from_storage(storage_context)

def get_query_engine(llama_eval_method, index, rerank_model=None, similarity_top_k=None, rerank_top_n=None):
    """Get the appropriate query engine based on evaluation method."""
    if llama_eval_method == "sentence_retrieval":
        return get_sentence_window_query_engine(
            sentence_index=index,
            rerank_model=rerank_model,
            similarity_top_k=similarity_top_k,
            rerank_top_n=rerank_top_n
        )
    elif llama_eval_method == "auto_merging_retrieval":
        return get_automerging_query_engine(
            automerging_index=index,
            rerank_model=rerank_model,
            similarity_top_k=similarity_top_k,
            rerank_top_n=rerank_top_n
        )
    elif llama_eval_method == "pagewise_retrieval":
        return get_pagewise_query_engine(
            pagewise_index=index,

        )
    else:
        raise ValueError(f"Unknown evaluation method: {llama_eval_method}")

def process_questions(llama_eval_method, cfg,question,case_id,prompt_template):
    """Process question function to handle the evaluation method."""
    if llama_eval_method == "sentence_retrieval":
        persist_dir = cfg["llama_index_cfg"]["sentence_retrieval"]["index_read_dir"]+"/"+str(case_id)+"_Redacted_cleaned"+"/sentence_windows_index"
        # Build storage context and load index
        print(F"Reference Index from {persist_dir}")
        storage_context = build_storage_context(persist_dir)
        index = load_index(storage_context)
        engine = get_query_engine(
        llama_eval_method,
        index,
        cfg["llm_cfg"]["rerank_model"],
        cfg["llama_index_cfg"][llama_eval_method]["similarity_top_k"],
        cfg["llama_index_cfg"][llama_eval_method]["rerank_top_n"]
    )
    elif llama_eval_method == "auto_merging_retrieval":
        persist_dir = cfg["llama_index_cfg"]["auto_merging_retrieval"]["index_read_dir"]+"/"+str(case_id)+"_Redacted_cleaned"+"/automerging_index"
        # Build storage context and load index
        print(F"Reference Index from {persist_dir}")
        storage_context = build_storage_context(persist_dir)
        index = load_index(storage_context)
        engine = get_query_engine(
        llama_eval_method,
        index,
        cfg["llm_cfg"]["rerank_model"],
        cfg["llama_index_cfg"][llama_eval_method]["similarity_top_k"],
        cfg["llama_index_cfg"][llama_eval_method]["rerank_top_n"]
    )
    elif llama_eval_method == "pagewise_retrieval":
        persist_dir = cfg["llama_index_cfg"]["pagewise_rag"]["index_read_dir"]+"/"+str(case_id)+"_Redacted_cleaned"+"/pagewise_index"
        # Build storage context and load index
        print(F"Reference Index from {persist_dir}")
        storage_context = build_storage_context(persist_dir)
        index = load_index(storage_context)
        engine = get_query_engine(
        llama_eval_method,
        index
    )
    else:
        raise ValueError(f"Unsupported llama_eval_method: {llama_eval_method}")

    # Build storage context and load index
    # print(F"Reference Index from {persist_dir}")
    # storage_context = build_storage_context(persist_dir)
    # index = load_index(storage_context)
    # Create prompt template
    prompt_template = create_prompt_template(prompt_template)
    # Format the prompt using the template
    formatted_prompt = prompt_template.format(query=question)
    # # Get query engine
    # engine = get_query_engine(
    #     llama_eval_method,
    #     index,
    #     cfg["llm_cfg"]["rerank_model"],
    #     cfg["llama_index_cfg"][llama_eval_method]["similarity_top_k"],
    #     cfg["llama_index_cfg"][llama_eval_method]["rerank_top_n"]
    # )

    # Perform the query
    response = engine.query(formatted_prompt)
    return response
    #print(str(window_response))

questions_df = pd.read_excel(os.path.join(here(cfg["eval_questions_dir"]), cfg["eval_file_name"]))
for idx, row in questions_df.iterrows():
    inference_start_time = time.time()
    question = row["question"]
    case_id = row["case_id"]  
    prompt_template=row["ai_prompt_for_question"]
    #print(F"CaseID: {case_id} Question: {question}")
    #result=process_questions("auto_merging_retrieval", cfg,question,case_id,prompt_template)
    result=process_questions("pagewise_retrieval",cfg,question,case_id,prompt_template)
    #print(F"Model Answer: {result}")
#     result = engine.query(question)
    infernece_time = time.time() - inference_start_time
    answer = result.response
    column_name = f"llama_index_{llama_eval_method}_result"
    questions_df.at[idx, column_name] = answer
    time_column_name = f"llama_index_{llama_eval_method}_inference_time"
    questions_df.at[idx, time_column_name] = round(infernece_time, 2)
    terminal_message = f"CaseID: {case_id} Question {idx}:\n{question}\nAnswer:{answer}"
    print(terminal_message)
    print(f"Inference time: {infernece_time}")
    print("--------------------------------------")

questions_df.to_excel(
    os.path.join(here(cfg["eval_questions_dir"]), cfg["eval_file_name"]), index=False)
print(
    f"Execution was successful and results are saved in  {cfg['eval_file_name']} \n\n")
end_time = time.time()
execution_time = end_time - start_time
print(f"Execution Time: {round(execution_time, 2)} seconds or {round(execution_time, 2)/60} minutes")
