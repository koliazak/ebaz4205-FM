#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

#define S2MM_CR      0x30 / 4
#define S2MM_SR      0x34 / 4
#define S2MM_DA      0x48 / 4
#define S2MM_LENGTH  0x58 / 4

#define RAM_BUFFER_ADDR 0x0FE00000 
#define TRANSFER_LEN    2048       

int main() {
    int fd_uio = open("/dev/uio0", O_RDWR);
    volatile uint32_t *dma_regs = (volatile uint32_t *)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd_uio, 0);

    int fd_mem = open("/dev/mem", O_RDWR | O_SYNC);
    volatile uint8_t *audio_buf = (volatile uint8_t *)mmap(NULL, 0x200000, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem, RAM_BUFFER_ADDR);


    FILE *f_out = fopen("record.raw", "wb");
    if (!f_out) {
        perror("Помилка створення файлу");
        return 1;
    }

    dma_regs[S2MM_CR] = 0x1001;          
    dma_regs[S2MM_DA] = RAM_BUFFER_ADDR; 

    uint32_t unmask = 1;
    uint32_t irq_count;


    int packets_to_record = 500;
    
    printf("Starting record. Wait...\n");

    for (int i = 0; i < packets_to_record; i++) {
        write(fd_uio, &unmask, sizeof(unmask));
        dma_regs[S2MM_LENGTH] = TRANSFER_LEN;
        
        // reading data
        read(fd_uio, &irq_count, sizeof(irq_count));
        dma_regs[S2MM_SR] = 0x1000;

        uint8_t file_buf[1024]; // 512 samples * 2 bytes each
        for (int j = 0; j < 512; j++) {
            file_buf[j*2 + 0] = audio_buf[j*4 + 1]; // left channel
            file_buf[j*2 + 1] = audio_buf[j*4 + 0]; // right channel
        }
        
        fwrite(file_buf, 1, 1024, f_out);
    }

    printf("Record is finished! File saved as 'record.raw'\n");
    
    fclose(f_out);
    return 0;
}
