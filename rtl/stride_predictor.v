
module stride_predictor (
    input  wire        clk,
    input  wire        rst,

    // Each input represents one CPU cache-line access
    input  wire        access_valid,
    input  wire [27:0] line_addr,

    // Predicted future cache line
    output reg         prefetch_valid,
    output reg  [27:0] prefetch_line
);

    // Previous observed cache-line address
    reg [27:0] last_line;

    // Previously detected stride
    reg signed [28:0] stride;

    // Predictor training state
    reg history_valid;
    reg stride_valid;

    // 2-bit saturating confidence counter
    reg [1:0] confidence;

    // Signed difference between current and previous line
    wire signed [28:0] current_stride;

    assign current_stride =
        $signed({1'b0, line_addr}) -
        $signed({1'b0, last_line});

    always @(posedge clk) begin

        if (rst) begin
            last_line      <= 28'b0;
            stride         <= 29'sd0;
            history_valid  <= 1'b0;
            stride_valid   <= 1'b0;
            confidence     <= 2'b00;

            prefetch_valid <= 1'b0;
            prefetch_line  <= 28'b0;
        end

        else begin

            // Default: no prediction this cycle
            prefetch_valid <= 1'b0;

            if (access_valid) begin

                if (!history_valid) begin

                    // First observed access
                    last_line     <= line_addr;
                    history_valid <= 1'b1;

                end

                else begin

                    // A non-zero stride is useful for prefetching
                    if (current_stride == 0) begin

                        // confidence   <= 2'b00;
                        // stride_valid <= 1'b0;

                    end

                    else if (!stride_valid) begin

                        // First stride observation
                        stride        <= current_stride;
                        stride_valid  <= 1'b1;
                        confidence    <= 2'b01;

                    end

                    else if (current_stride == stride) begin

                        // Stride pattern continues
                        if (confidence < 3)
                            confidence <= confidence + 1'b1;

                        // Confidence threshold reached:
                        // predict one stride ahead
                        if (confidence >= 1) begin

                            prefetch_valid <= 1'b1;
                            prefetch_line  <=
                                line_addr + stride[27:0];

                        end

                    end

                    else begin

                        // Pattern changed: start learning new stride
                        stride       <= current_stride;
                        confidence   <= 2'b01;
                        stride_valid <= 1'b1;

                    end

                    // Always remember the latest access
                    last_line <= line_addr;

                end
            end
        end
    end

endmodule
