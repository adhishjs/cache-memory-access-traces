
module prefetch_controller (

    input wire clk,
    input wire rst,

    // Prediction from stride predictor
    input wire prefetch_valid,
    input wire [27:0] prefetch_line,

    // Main cache presence check
    output reg check_cache,
    output reg [27:0] check_cache_line,
    input wire cache_present,

    // Prefetch buffer presence check
    output reg check_buffer,
    output reg [27:0] check_buffer_line,
    input wire buffer_present,

    // Arbiter interface
    output reg prefetch_req,
    output reg [31:0] prefetch_addr,
    input wire prefetch_accept,
    input wire prefetch_resp_valid,
    input wire [127:0] prefetch_resp_data,

    // Prefetch buffer insertion
    output reg buffer_insert,
    output reg [27:0] buffer_insert_line,
    output reg [127:0] buffer_insert_data,

    // Status
    output reg prefetch_done,
    output reg [31:0] duplicate_count,
    output reg [31:0] issued_count,

    // Pending-prediction queue diagnostics
    output reg [31:0] pending_capture_count,
    output reg [31:0] pending_overwrite_count,
    output reg [31:0] pending_consume_count,

    output wire prefetch_busy,
    output wire [27:0] prefetch_active_line
);

    localparam IDLE       = 3'd0;
    localparam CHECK      = 3'd1;
    localparam ISSUE      = 3'd2;
    localparam WAIT_RESP  = 3'd3;
    localparam INSERT     = 3'd4;

    reg [2:0] state;

    reg [27:0] saved_line;
    reg pending_valid;
    reg [27:0] pending_line;
    assign prefetch_busy = (state != IDLE);
    assign prefetch_active_line = saved_line;
    always @(posedge clk) begin

        if (rst) begin
            state <= IDLE;
            saved_line <= 0;
pending_valid <= 0;
pending_line <= 0;
            check_cache <= 0;
            check_cache_line <= 0;

            check_buffer <= 0;
            check_buffer_line <= 0;

            prefetch_req <= 0;
            prefetch_addr <= 0;

            buffer_insert <= 0;
            buffer_insert_line <= 0;
            buffer_insert_data <= 0;

            prefetch_done <= 0;
            duplicate_count <= 0;
            issued_count <= 0;

            pending_capture_count <= 0;
            pending_overwrite_count <= 0;
            pending_consume_count <= 0;
        end

        else begin

            // Default one-cycle pulses
            check_cache <= 0;
            check_buffer <= 0;
            buffer_insert <= 0;
            prefetch_done <= 0;
            // Pending-slot policy:
            // - While busy, keep the newest prediction in the one-entry slot.
            // - In IDLE, consume an older pending prediction first.
            // - If a new prediction arrives on that same IDLE cycle, save it
            //   in the slot for the next transaction (do not lose the pulse).
            if (state != IDLE && prefetch_valid) begin
                if (pending_valid) begin
                    pending_overwrite_count <= pending_overwrite_count + 1'b1;
                    // Debug: the old pending line is being replaced by a newer prediction.
                    $display("PENDING_OVERWRITE time=%0t state=%0d old_line=0x%07h new_line=0x%07h",
                             $time, state, pending_line, prefetch_line);
                end
                else begin
                    pending_capture_count <= pending_capture_count + 1'b1;
                end

                pending_valid <= 1'b1;
                pending_line <= prefetch_line;
            end
            else if (state == IDLE && pending_valid && prefetch_valid) begin
                // Old pending prediction becomes active; new one takes its place.
                pending_consume_count <= pending_consume_count + 1'b1;
                pending_capture_count <= pending_capture_count + 1'b1;
                pending_valid <= 1'b1;
                pending_line <= prefetch_line;
            end
            else if (state == IDLE && pending_valid && !prefetch_valid) begin
                pending_consume_count <= pending_consume_count + 1'b1;
                pending_valid <= 1'b0;
            end

            case (state)

IDLE: begin
    prefetch_req <= 0;

    if (pending_valid) begin

        saved_line <= pending_line;

        check_cache_line <= pending_line;
        check_buffer_line <= pending_line;

        check_cache <= 1;
        check_buffer <= 1;

        state <= CHECK;

    end

    else if (prefetch_valid) begin

        saved_line <= prefetch_line;

        check_cache_line <= prefetch_line;
        check_buffer_line <= prefetch_line;

        check_cache <= 1;
        check_buffer <= 1;

        state <= CHECK;

    end
end

                CHECK: begin

                    if (cache_present || buffer_present) begin
                        duplicate_count <= duplicate_count + 1;
                        prefetch_done <= 1;
                        state <= IDLE;
                    end

                    else begin
                        prefetch_addr <= {saved_line, 4'b0000};
                        prefetch_req <= 1;
                        state <= ISSUE;
                    end

                end

                ISSUE: begin

                    if (prefetch_accept) begin
                        prefetch_req <= 0;
                        issued_count <= issued_count + 1;
                        state <= WAIT_RESP;
                    end

                end

                WAIT_RESP: begin

                    if (prefetch_resp_valid) begin
                        buffer_insert_line <= saved_line;
                        buffer_insert_data <= prefetch_resp_data;
                        state <= INSERT;
                    end

                end

                INSERT: begin

                    buffer_insert <= 1;
                    prefetch_done <= 1;
                    state <= IDLE;

                end

                default: begin
                    state <= IDLE;
                    prefetch_req <= 0;
                end

            endcase
        end
    end

endmodule
