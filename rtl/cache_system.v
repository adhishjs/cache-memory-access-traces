
module cache_system (
    input wire clk,
    input wire rst,

    // CPU interface
    input wire cpu_req,
    input wire [31:0] cpu_addr,
    output wire [31:0] cpu_rdata,
    output wire cpu_ready
);

    // =================================================
    // 1. CACHE CONTROLLER SIGNALS
    // =================================================



    wire prefetch_busy;
    wire [27:0] prefetch_active_line;

    wire demand_req;
    wire [31:0] demand_addr;
    wire demand_accept;
    wire demand_resp_valid;
    wire [127:0] demand_resp_data;

    wire pb_lookup;
    wire [27:0] pb_lookup_line;
    wire pb_hit;
    wire [127:0] pb_hit_data;

    wire pb_consume;
    wire [27:0] pb_consume_line;

    wire cache_probe_hit;

    // CPU access information for predictor
    wire access_valid;
    wire [27:0] access_line;

    // =================================================
    // 2. PREFETCH BUFFER SIGNALS
    // =================================================

    wire pb_insert;
    wire [27:0] pb_insert_line;
    wire [127:0] pb_insert_data;

    wire buffer_probe_hit;

    // =================================================
    // 3. STRIDE PREDICTOR SIGNALS
    // =================================================

    wire predictor_valid;
    wire [27:0] predictor_line;

    // =================================================
    // 4. PREFETCH CONTROLLER SIGNALS
    // =================================================

    wire check_cache;
    wire [27:0] check_cache_line;

    wire check_buffer;
    wire [27:0] check_buffer_line;

    wire prefetch_req;
    wire [31:0] prefetch_addr;
    wire prefetch_accept;

    wire prefetch_resp_valid;
    wire [127:0] prefetch_resp_data;

    wire prefetch_done;
    wire [31:0] duplicate_count;
    wire [31:0] issued_count;

    // =================================================
    // 5. DRAM SIGNALS
    // =================================================

    wire dram_req;
    wire [31:0] dram_addr;
    wire dram_busy;
    wire dram_resp_valid;
    wire [127:0] dram_resp_data;

    // =================================================
    // 6. CACHE CONTROLLER
    // =================================================

    cache_controller cache (
        .clk(clk),
        .rst(rst),

        .cpu_req(cpu_req),
        .cpu_addr(cpu_addr),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),

        .demand_req(demand_req),
        .demand_addr(demand_addr),
        .demand_accept(demand_accept),
        .demand_resp_valid(demand_resp_valid),
        .demand_resp_data(demand_resp_data),

        .pb_lookup(pb_lookup),
        .pb_lookup_line(pb_lookup_line),
        .pb_hit(pb_hit),
        .pb_hit_data(pb_hit_data),

        .pb_consume(pb_consume),
        .pb_consume_line(pb_consume_line),

        .probe_valid(check_cache),
        .probe_line(check_cache_line),
        .probe_hit(cache_probe_hit),

        .access_valid(access_valid),
        .access_line(access_line),

        .prefetch_busy(prefetch_busy),
        .prefetch_active_line(prefetch_active_line),
        .prefetch_done(prefetch_done)
    );

    // =================================================
    // 7. STRIDE PREDICTOR
    // =================================================

    stride_predictor predictor (
        .clk(clk),
        .rst(rst),

        .access_valid(access_valid),
        .line_addr(access_line),

        .prefetch_valid(predictor_valid),
        .prefetch_line(predictor_line)
    );

    // =================================================
    // 8. PREFETCH BUFFER
    // =================================================

    prefetch_buffer pb (
        .clk(clk),
        .rst(rst),

        .insert(pb_insert),
        .insert_line(pb_insert_line),
        .insert_data(pb_insert_data),

        .lookup(pb_lookup),
        .lookup_line(pb_lookup_line),
        .hit(pb_hit),
        .hit_data(pb_hit_data),

        .consume(pb_consume),
        .consume_line(pb_consume_line),

        .probe_valid(check_buffer),
        .probe_line(check_buffer_line),
        .probe_hit(buffer_probe_hit)
    );

    // =================================================
    // 9. PREFETCH CONTROLLER
    // =================================================

    prefetch_controller prefetch_ctrl (
        .clk(clk),
        .rst(rst),

        .prefetch_valid(predictor_valid),
        .prefetch_line(predictor_line),

        .check_cache(check_cache),
        .check_cache_line(check_cache_line),
        .cache_present(cache_probe_hit),

        .check_buffer(check_buffer),
        .check_buffer_line(check_buffer_line),
        .buffer_present(buffer_probe_hit),

        .prefetch_req(prefetch_req),
        .prefetch_addr(prefetch_addr),
        .prefetch_accept(prefetch_accept),
        .prefetch_resp_valid(prefetch_resp_valid),
        .prefetch_resp_data(prefetch_resp_data),

        .prefetch_busy(prefetch_busy),
        .prefetch_active_line(prefetch_active_line),

        .buffer_insert(pb_insert),
        .buffer_insert_line(pb_insert_line),
        .buffer_insert_data(pb_insert_data),

        .prefetch_done(prefetch_done),
        .duplicate_count(duplicate_count),
        .issued_count(issued_count)
    );

    // =================================================
    // 10. DRAM ARBITER
    // =================================================

    dram_arbiter arbiter (
        .clk(clk),
        .rst(rst),

        // Demand path
        .demand_req(demand_req),
        .demand_addr(demand_addr),
        .demand_accept(demand_accept),
        .demand_resp_valid(demand_resp_valid),
        .demand_resp_data(demand_resp_data),

        // Prefetch path
        .prefetch_req(prefetch_req),
        .prefetch_addr(prefetch_addr),
        .prefetch_accept(prefetch_accept),
        .prefetch_resp_valid(prefetch_resp_valid),
        .prefetch_resp_data(prefetch_resp_data),

        // DRAM interface
        .dram_req(dram_req),
        .dram_addr(dram_addr),
        .dram_busy(dram_busy),
        .dram_resp_valid(dram_resp_valid),
        .dram_resp_data(dram_resp_data)
    );

    // =================================================
    // 11. DRAM MODEL
    // =================================================

    dram_model #(
        .LATENCY(20),
        .MEM_WORDS(16384)
    ) dram (
        .clk(clk),
        .rst(rst),

        .dram_req(dram_req),
        .dram_addr(dram_addr),
        .dram_busy(dram_busy),

        .resp_valid(dram_resp_valid),
        .resp_data(dram_resp_data)
    );

endmodule
