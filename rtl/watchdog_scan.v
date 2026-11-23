`timescale 1ns/1ps

module watchdog_scan #(
    parameter [7:0] RELOAD_VALUE = 8'd10
) (
    input  wire clk,
    input  wire rst_n,
    input  wire kick,
    input  wire scan_enable,
    input  wire scan_in,
    output wire scan_out,
    output wire timeout
);
    reg [7:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= RELOAD_VALUE;
        else if (scan_enable)
            count <= {count[6:0], scan_in};
        else if (kick)
            count <= RELOAD_VALUE;
        else if (count != 8'd0)
            count <= count - 8'd1;
        // With no assignment at zero, the counter holds its value.
    end

    assign scan_out = count[7];
    assign timeout = !scan_enable && (count == 8'd0);
endmodule
