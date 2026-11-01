
module dram_arbiter (
    input wire clk,
    input wire rst,

    // Demand request from cache controller
    input wire demand_req,
    input wire [31:0] demand_addr,
    output reg demand_accept,
    output reg demand_resp_valid,
    output reg [127:0] demand_resp_data,

    // Prefetch request from prefetch engine
    input wire prefetch_req,
    input wire [31:0] prefetch_addr,
    output reg prefetch_accept,
    output reg prefetch_resp_valid,
    output reg [127:0] prefetch_resp_data,

    // DRAM interface
    output wire dram_req,
    output wire [31:0] dram_addr,
    input wire dram_busy,
    input wire dram_resp_valid,
    input wire [127:0] dram_resp_data
);

    // Transaction tracking
    reg active;
    reg cooldown;
    reg owner_prefetch;

    // Select demand first, otherwise prefetch
    assign dram_req =
        !active && !dram_busy &&
        (demand_req || prefetch_req);

    assign dram_addr =
        demand_req ? demand_addr : prefetch_addr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            active <= 0;
            owner_prefetch <= 0;
            cooldown <= 0;
            demand_accept <= 0;
            prefetch_accept <= 0;

            demand_resp_valid <= 0;
            prefetch_resp_valid <= 0;

            demand_resp_data <= 0;
            prefetch_resp_data <= 0;
        end
        else begin
            // Default: acceptance and response are pulses
            demand_accept <= 0;
            prefetch_accept <= 0;

            demand_resp_valid <= 0;
            prefetch_resp_valid <= 0;

            // A transaction has completed
            if (active && dram_resp_valid) begin

                if (owner_prefetch) begin
                    prefetch_resp_valid <= 1;
                    prefetch_resp_data <= dram_resp_data;
                end
                else begin
                    demand_resp_valid <= 1;
                    demand_resp_data <= dram_resp_data;
                end

                active <= 0;
                cooldown <= 1;
            end

            else if (cooldown) begin
                cooldown <= 0;
            end

            else if (!active && !dram_busy &&
                    (demand_req || prefetch_req)) begin

                active <= 1;

                if (demand_req) begin
                    owner_prefetch <= 0;
                    demand_accept <= 1;
                end
                else begin
                    owner_prefetch <= 1;
                    prefetch_accept <= 1;
                end
            end
        end
    end

endmodule
