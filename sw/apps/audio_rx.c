#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

// AXI DMA (S2MM) register offsets
#define S2MM_CR      0x30 / 4   // Control Register
#define S2MM_SR      0x34 / 4   // Status Register
#define S2MM_DA      0x48 / 4   // Destination Address
#define S2MM_LENGTH  0x58 / 4   // Transfer Length

#define RAM_BUFFER_ADDR 0x0FE00000 // Reserved memory. See system-user.dtsi
#define TRANSFER_LEN    2048       // 512 samples * 4 bytes

int main() {
    int fd_uio = open("/dev/uio0", O_RDWR);
    volatile uint32_t *dma_regs = (volatile uint32_t *)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd_uio, 0);

    int fd_mem = open("/dev/mem", O_RDWR | O_SYNC);
    volatile uint8_t *audio_buf = (volatile uint8_t *)mmap(NULL, 0x200000, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem, RAM_BUFFER_ADDR);

    printf("DMA and RAM mapped successfully!\n");

    
    dma_regs[S2MM_CR] = 0x1001;          // Bit 0 = Run, bit 12 = Enable Interrupts (IOC_IrqEn)
    dma_regs[S2MM_DA] = RAM_BUFFER_ADDR; // Where to write

    uint32_t unmask = 1;
    uint32_t irq_count;


    while (1) {
        write(fd_uio, &unmask, sizeof(unmask));

        // Start transaction
        dma_regs[S2MM_LENGTH] = TRANSFER_LEN;

        // Program sleeps. Wakes up when FIFO recieves 2048's byte and activates tlast
        read(fd_uio, &irq_count, sizeof(irq_count));
        
        uint32_t status = dma_regs[S2MM_SR];
        
        // Reset all possible interrupts: IOC_Irq (bit 12), Dly_Irq (bit 13), Err_Irq (bit 14)
        dma_regs[S2MM_SR] = 0x7000;
  
        // Catch errors and reset
        if (status & 0x00000001) {
            printf("WARNING: DMA Halted! Status = 0x%08x. Reset...\n", status);
            
            // reset
            dma_regs[S2MM_CR] = 0x0004;
            while(dma_regs[S2MM_CR] & 0x0004);
         
            // start again
            dma_regs[S2MM_CR] = 0x1001;
            dma_regs[S2MM_DA] = RAM_BUFFER_ADDR; 
            continue;
        }
       
        // printf("Sample: %02x %02x %02x %02x\n", audio_buf[0], audio_buf[1], audio_buf[2], audio_buf[3]);
        uint8_t out_buf[1024];
        for (int j = 0; j < 512; j++) {
            out_buf[j*2+0] = audio_buf[j*4+1]; // left
            out_buf[j*2+1] = audio_buf[j*4+0];  // right
        }
        fwrite(out_buf, sizeof(uint8_t), sizeof(out_buf), stdout);
        fflush(stdout);
    }

    return 0;
}
