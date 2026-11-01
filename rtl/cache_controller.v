
module cache_controller (
    input wire clk,
    input wire rst,

    // CPU interface
    input wire cpu_req,
    input wire [31:0] cpu_addr,
    output reg [31:0] cpu_rdata,
    output reg cpu_ready,

    // Demand DRAM arbiter interface
    output wire demand_req,
    output wire [31:0] demand_addr,
    input wire demand_accept,
    input wire demand_resp_valid,
    input wire [127:0] demand_resp_data,

    // Prefetch buffer interface
    output wire pb_lookup,
    output wire [27:0] pb_lookup_line,
    input wire pb_hit,
    input wire [127:0] pb_hit_data,

    output wire pb_consume,
    output wire [27:0] pb_consume_line,


input wire prefetch_busy,
input wire [27:0] prefetch_active_line,
input wire prefetch_done,


    // NEW: Combinational duplicate-check interface
    input wire probe_valid,
    input wire [27:0] probe_line,
    output wire probe_hit,
        // CPU access information for stride predictor
    output reg access_valid,
    output reg [27:0] access_line
);

    // ------------------------------------------------
    // 1 KB direct-mapped cache, 16-byte lines
    // ------------------------------------------------

    reg [127:0] data_mem [0:63];
    reg [21:0] tag_mem [0:63];
    reg valid_mem [0:63];

    // ------------------------------------------------
    // FSM states
    // ------------------------------------------------

localparam IDLE         = 4'd0;
localparam LOOKUP       = 4'd1;
localparam PB_LOOKUP    = 4'd2;
localparam PB_WAIT      = 4'd3;
localparam RECHECK      = 4'd4;
localparam RECHECK_WAIT = 4'd5;
localparam MISS_REQ     = 4'd6;
localparam MISS_WAIT    = 4'd7;
localparam FILL         = 4'd8;
localparam RESPOND      = 4'd9;
localparam WAIT_PREFETCH = 4'd10;


    reg [3:0] state;

    reg [31:0] saved_addr;

    // ------------------------------------------------
    // Address fields
    // ------------------------------------------------

    wire [21:0] req_tag;
    wire [5:0] req_index;
    wire [1:0] req_word;

    assign req_tag = saved_addr[31:10];
    assign req_index = saved_addr[9:4];
    assign req_word = saved_addr[3:2];

    // ------------------------------------------------
    // Demand DRAM interface
    // ------------------------------------------------

    assign demand_req = (state == MISS_REQ);

    assign demand_addr =
        {saved_addr[31:4], 4'b0000};

    // ------------------------------------------------
    // Prefetch buffer synchronous lookup
    // ------------------------------------------------

    assign pb_lookup = (state == PB_LOOKUP) || (state == RECHECK);

    assign pb_lookup_line = saved_addr[31:4];

    assign pb_consume =
        (state == PB_WAIT) && pb_hit;

    assign pb_consume_line = saved_addr[31:4];

    // ------------------------------------------------
    // NEW: Combinational main-cache duplicate check
    // ------------------------------------------------

    assign probe_hit =
        probe_valid &&
        valid_mem[probe_line[5:0]] &&
        (tag_mem[probe_line[5:0]] == probe_line[27:6]);

    // ------------------------------------------------
    // Counters
    // ------------------------------------------------

    integer i;
    integer hit_count;
    integer miss_count;
    integer prefetch_hit_count;
    integer demand_miss_count;

    // ------------------------------------------------
    // Main cache controller
    // ------------------------------------------------

    always @(posedge clk) begin

        if (rst) begin
            state <= IDLE;
            saved_addr <= 0;
            cpu_rdata <= 0;
            cpu_ready <= 0;

            hit_count <= 0;
            miss_count <= 0;
            prefetch_hit_count <= 0;
            demand_miss_count <= 0;

            access_valid <= 0;
            access_line <= 0;

            for (i = 0; i < 64; i = i + 1) begin
                data_mem[i] <= 0;
                tag_mem[i] <= 0;
                valid_mem[i] <= 0;
            end
        end

        else begin
            cpu_ready <= 0;
            access_valid <= 0;
            case (state)

                IDLE: begin
                    if (cpu_req) begin
                        saved_addr <= cpu_addr;

                        // Send accepted CPU cache-line access to predictor
                        access_valid <= 1'b1;
                        access_line <= cpu_addr[31:4];

                        state <= LOOKUP;
                    end
                end

                // Main cache lookup
                LOOKUP: begin

                    if (valid_mem[req_index] &&
                        tag_mem[req_index] == req_tag) begin

                        hit_count <= hit_count + 1;

                        cpu_rdata <=
                            data_mem[req_index][req_word*32 +: 32];

                        state <= RESPOND;
                    end

                    else begin
                        miss_count <= miss_count + 1;
                        state <= PB_LOOKUP;
                    end

                end

                // Prefetch buffer lookup
                PB_LOOKUP: begin
                    state <= PB_WAIT;
                end

PB_WAIT: begin

    if (pb_hit) begin

        prefetch_hit_count <= prefetch_hit_count + 1;

        data_mem[req_index] <= pb_hit_data;
        tag_mem[req_index] <= req_tag;
        valid_mem[req_index] <= 1'b1;

        cpu_rdata <=
            pb_hit_data[req_word*32 +: 32];

        state <= RESPOND;

    end

    else if (prefetch_busy &&
             prefetch_active_line == saved_addr[31:4]) begin

        state <= WAIT_PREFETCH;

    end

    else begin
        state <= RECHECK;
    end

end

                RECHECK: begin
                    state <= RECHECK_WAIT;
                end

                RECHECK_WAIT: begin

                    if (pb_hit) begin

                        prefetch_hit_count <= prefetch_hit_count + 1;

                        data_mem[req_index] <= pb_hit_data;
                        tag_mem[req_index] <= req_tag;
                        valid_mem[req_index] <= 1'b1;

                        cpu_rdata <=
                            pb_hit_data[req_word*32 +: 32];

                        state <= RESPOND;

                    end
                    else begin
                        state <= MISS_REQ;
                    end

                end


                WAIT_PREFETCH: begin

                    if (prefetch_done) begin
                        // Prefetch has been inserted into the buffer.
                        state <= RECHECK;
                    end

                end


                // Demand request through arbiter
                MISS_REQ: begin

                    if (demand_accept) begin

                        demand_miss_count <=
                            demand_miss_count + 1;

                        state <= MISS_WAIT;

                    end

                end

                // Wait for DRAM response
                MISS_WAIT: begin

                    if (demand_resp_valid) begin

                        data_mem[req_index] <= demand_resp_data;
                        tag_mem[req_index] <= req_tag;
                        valid_mem[req_index] <= 1'b1;

                        state <= FILL;

                    end

                end

                // Return requested word
                FILL: begin

                    cpu_rdata <=
                        data_mem[req_index][req_word*32 +: 32];

                    state <= RESPOND;

                end

                RESPOND: begin
                    cpu_ready <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
    