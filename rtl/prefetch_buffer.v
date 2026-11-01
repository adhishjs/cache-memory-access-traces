
module prefetch_buffer (
    input wire clk,
    input wire rst,

    // Insert a prefetched cache line
    input wire insert,
    input wire [27:0] insert_line,
    input wire [127:0] insert_data,

    // Search for a requested cache line
    input wire lookup,
    input wire [27:0] lookup_line,
    output reg hit,
    output reg [127:0] hit_data,

    // Consume an entry after using it
    input wire consume,
    input wire [27:0] consume_line,

    // NEW: Combinational duplicate-check interface
    input wire probe_valid,
    input wire [27:0] probe_line,
    output reg probe_hit
);

    // Four entries
    reg valid [0:3];
    reg [27:0] line_addr [0:3];
    reg [127:0] data [0:3];

    // Round-robin replacement pointer
    reg [1:0] replace_ptr;

    integer i;
    integer p;
    reg found;

    // ------------------------------------------------
    // NEW: Combinational lookup for duplicate checking
    // ------------------------------------------------

    always @(*) begin
        probe_hit = 0;

        if (probe_valid) begin
            for (p = 0; p < 4; p = p + 1) begin
                if (valid[p] && line_addr[p] == probe_line)
                    probe_hit = 1;
            end
        end
    end

    // ------------------------------------------------
    // Existing synchronous lookup, consume and insert
    // ------------------------------------------------

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            replace_ptr <= 0;
            hit <= 0;
            hit_data <= 0;

            for (i = 0; i < 4; i = i + 1) begin
                valid[i] <= 0;
                line_addr[i] <= 0;
                data[i] <= 0;
            end
        end

        else begin
            hit <= 0;
            hit_data <= 0;

            // 1. Search for a requested line
            if (lookup) begin
                found = 0;

                for (i = 0; i < 4; i = i + 1) begin
                    if (valid[i] &&
                        line_addr[i] == lookup_line &&
                        !found) begin

                        hit <= 1;
                        hit_data <= data[i];
                        found = 1;
                    end
                end
            end

            // 2. Invalidate a consumed entry
            if (consume) begin
                for (i = 0; i < 4; i = i + 1) begin
                    if (valid[i] &&
                        line_addr[i] == consume_line) begin
                        valid[i] <= 0;
                    end
                end
            end

            // 3. Insert a new prefetched line
            if (insert) begin
                valid[replace_ptr] <= 1;
                line_addr[replace_ptr] <= insert_line;
                data[replace_ptr] <= insert_data;

                replace_ptr <= replace_ptr + 1'b1;
            end
        end
    end

endmodule
