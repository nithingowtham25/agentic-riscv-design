# Task 1 RAG Retrieval Observation

## Method

A semantic FAISS index was built from 23 files in `rag_dataset/`, producing 25 overlapping text chunks with the `sentence-transformers/all-MiniLM-L6-v2` embedding model. Five representative engineering queries were issued, and the top five retrieved chunks for each query were saved in `logs/task1_rag_queries.txt`.

## Observation

The retrieved context was relevant to the engineering intent of all five queries. The controller/PCSrc/branch query returned PC redirection behavior, branch-condition details, datapath integration guidance, and fixed module interfaces. This is useful for diagnosing control-flow errors such as swapped branch conditions, missing equality handling for BGE, incorrect PC target selection, or invalid module-port connections.

The signed arithmetic-shift query returned the RV32I ALU reference and the specific shift-bug note that requires `B[4:0]` as the shift amount and `$signed(A) >>> B[4:0]` for SRA. It also returned signed-comparison guidance, which is relevant because signedness mistakes frequently occur alongside arithmetic-shift errors. The Icarus query retrieved compile-message explanations, undeclared-signal and port-mismatch guidance, and the module-interface reference; these sources directly support classifying and repairing compilation failures.

The datapath JAL/JALR query retrieved interface constraints, PC redirection behavior, ALU operand selection, and PC+4 writeback guidance. These are the key integration relationships needed to connect the eight modules. The load/store query retrieved load/store sizing and memory-addressing material, although its highest-ranked chunk was an immediate-encoding reference. This shows that semantic retrieval can surface related RV32I context rather than only exact keyword matches; therefore the agent must verify retrieved information against the supplied `memory_access` specification before applying it.

## Conclusion

The RAG knowledge base provides useful specification, interface, common-bug, and simulator-diagnostic context for RTL generation and repair. Retrieval is most valuable when the query includes the affected module, behavior, and observed failure symptom. Retrieved chunks are supplemental evidence, not a replacement for the Assignment 2 module specifications: the agent must preserve the required interfaces and follow the current assignment specification whenever a retrieved chunk is incomplete, from a different project convention, or inconsistent with the requested design.