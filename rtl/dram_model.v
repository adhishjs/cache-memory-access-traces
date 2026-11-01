
module dram_model #(
    parameter integer LATENCY = 20,
    parameter integer MEM_WORDS = 16384
)(
    input  wire         clk,
    input  wire         rst,

    input  wire         dram_req,
    input  wire [31:0]  dram_addr,

    output reg          dram_busy,
    output reg          resp_valid,
    output reg  [127:0] resp_data
);

    // Behavioural memory: 4096 words x 32 bits
    reg [31:0] mem [0:MEM_WORDS-1];

    reg [31:0] saved_addr;
    integer count;
    integer base_word;
    integer i;

    localparam IDLE = 1'b0;
    localparam WAIT = 1'b1;

    reg state;

    // Initialize memory with deterministic test data
    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'hA5000000 ^ i;
    end

    always @(posedge clk) begin

        if (rst) begin
            state      <= IDLE;
            dram_busy  <= 1'b0;
            resp_valid <= 1'b0;
            resp_data  <= 128'b0;
            saved_addr <= 32'b0;
            count      <= 0;
        end

        else begin

            // Default: response is a one-cycle pulse
            resp_valid <= 1'b0;

            case (state)

                IDLE: begin
                    dram_busy <= 1'b0;

                    if (dram_req) begin
                        saved_addr <= dram_addr;
                        count      <= LATENCY;
                        dram_busy  <= 1'b1;
                        state      <= WAIT;
                    end
                end

                WAIT: begin
                    if (count > 1) begin
                        count <= count - 1;
                    end

                    else begin
                        base_word = saved_addr >> 2;

                        if ((base_word + 3) < MEM_WORDS) begin
                            resp_data <= {
                                mem[base_word + 3],
                                mem[base_word + 2],
                                mem[base_word + 1],
                                mem[base_word + 0]
                            };
                        end
                        else begin
                            resp_data <= 128'b0;
                        end

                        resp_valid <= 1'b1;
                        dram_busy  <= 1'b0;
                        state      <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule
