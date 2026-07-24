#pragma once

const char* SEARCH_DIR = 
#ifdef DATA_SEARCH_DIR
    DATA_SEARCH_DIR
#else
    ""
#endif
;