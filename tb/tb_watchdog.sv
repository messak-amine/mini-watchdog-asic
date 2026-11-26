`timescale 1ns/1ps

module tb_watchdog;
    localparam logic [7:0] RELOAD = 8'd10;
    localparam logic [7:0] SCAN_PATTERN = 8'b1011_0010;

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic kick = 1'b0;
    logic scan_enable = 1'b0;
    logic scan_in = 1'b0;
    wire scan_out;
    wire timeout;

    int reset_hits = 0;
    int countdown_hits = 0;
    int refresh_hits = 0;
    int timeout_hits = 0;
    int saturation_hits = 0;
    int scan_hits = 0;
    int mode_switch_hits = 0;

    watchdog_scan dut (
        .clk(clk),
        .rst_n(rst_n),
        .kick(kick),
        .scan_enable(scan_enable),
        .scan_in(scan_in),
        .scan_out(scan_out),
        .timeout(timeout)
    );

    always #5 clk = ~clk;

    task automatic step_clock;
        @(posedge clk);
        #1; // Sample after the register's nonblocking update.
    endtask

    task automatic check_state(
        input logic [7:0] expected_count,
        input logic expected_timeout,
        input string scenario
    );
        if (dut.count !== expected_count || timeout !== expected_timeout) begin
            $fatal(1, "FAIL at %0d ns (%s): count=%0d timeout=%b, expected count=%0d timeout=%b",
                   $time, scenario, dut.count, timeout, expected_count, expected_timeout);
        end
    endtask

    initial begin
        if ($test$plusargs("gate"))
            $dumpfile("build/watchdog_gate.vcd");
        else
            $dumpfile("build/watchdog.vcd");
        $dumpvars(0, tb_watchdog);

        #2;
        rst_n = 1'b0;
        #1;
        check_state(RELOAD, 1'b0, "asynchronous reset before first clock edge");
        reset_hits++;
        step_clock();
        check_state(RELOAD, 1'b0, "reset held across a clock edge");
        reset_hits++;
        @(negedge clk);
        rst_n = 1'b1;

        for (int cycle = 1; cycle <= 3; cycle++) begin
            step_clock();
            check_state(RELOAD - cycle[7:0], 1'b0, "countdown before kick");
            countdown_hits++;
        end

        @(negedge clk);
        kick = 1'b1;
        step_clock();
        check_state(RELOAD, 1'b0, "kick reloads partial count");
        refresh_hits++;
        @(negedge clk);
        kick = 1'b0;

        for (int cycle = 1; cycle < int'(RELOAD); cycle++) begin
            step_clock();
            check_state(RELOAD - cycle[7:0], 1'b0, "countdown without kick");
            countdown_hits++;
        end
        step_clock();
        check_state(8'd0, 1'b1, "timeout at zero");
        timeout_hits++;
        repeat (3) begin
            step_clock();
            check_state(8'd0, 1'b1, "saturation at zero");
            saturation_hits++;
        end

        @(negedge clk);
        scan_enable = 1'b1;
        kick = 1'b1; // Scan takes priority over kick.
        #1;
        check_state(8'd0, 1'b0, "enter scan while expired");
        mode_switch_hits++;

        // Load the MSB first so eight shifts leave SCAN_PATTERN in count.
        for (int bit_index = 7; bit_index >= 0; bit_index--) begin
            scan_in = SCAN_PATTERN[bit_index];
            step_clock();
            check_state(SCAN_PATTERN >> bit_index, 1'b0, "scan shift in");
            scan_hits++;
        end

        for (int bit_index = 7; bit_index >= 0; bit_index--) begin
            @(negedge clk);
            // The outgoing MSB is valid before the next rising edge.
            if (scan_out !== SCAN_PATTERN[bit_index]) begin
                $fatal(1, "FAIL at %0d ns: scan_out bit %0d=%b, expected %b",
                       $time, bit_index, scan_out, SCAN_PATTERN[bit_index]);
            end
            scan_in = (bit_index == 0); // Leave count at 1 after readout.
            step_clock();
            if (timeout !== 1'b0)
                $fatal(1, "FAIL at %0d ns: timeout must be low in scan mode", $time);
            scan_hits++;
        end

        @(negedge clk);
        kick = 1'b0;
        scan_enable = 1'b0;
        #1;
        check_state(8'd1, 1'b0, "exit scan with shifted-in count");
        mode_switch_hits++;
        step_clock();
        check_state(8'd0, 1'b1, "functional decrement after scan");
        mode_switch_hits++;

        @(negedge clk);
        kick = 1'b1;
        step_clock();
        check_state(RELOAD, 1'b0, "kick clears timeout");
        refresh_hits++;

        $display("Scenario hits  reset=%0d countdown=%0d refresh=%0d timeout=%0d",
                 reset_hits, countdown_hits, refresh_hits, timeout_hits);
        $display("               saturation=%0d scan=%0d mode_switch=%0d",
                 saturation_hits, scan_hits, mode_switch_hits);
        $display("PASS: all watchdog checks passed");
        $finish;
    end
endmodule
