#ifndef COMPILER_HPP
#define COMPILER_HPP

#include "il.hpp"
#include "ast.hpp"
#include "error.hpp"

#include <map>
#include <optional>

namespace LoLa::Compiler
{
    struct Function
    {
        uint32_t entry_point;
        uint16_t local_count;
    };

    //! piece of compiled LoLa code
    struct CompilationUnit
    {
        std::vector<uint8_t> code;
        std::map<std::string, Function> functions;
    };

    struct Label {
        std::uint32_t value;

        bool operator==(Label other) const {
            return value == other.value;
        }
        bool operator!=(Label other) const {
            return value != other.value;
        }
        bool operator<(Label other) const {
            return value < other.value;
        }
    };

    struct CodeWriter
    {
        Label next_label;
        std::map<Label, uint32_t> labels;
        CompilationUnit * target;
        std::vector<std::pair<Label, uint32_t>> patches;

        explicit CodeWriter(CompilationUnit * target);

        //! create a new label identifier
        Label createLabel();

        //! sets the label to the current address
        void defineLabel(Label lbl);

        //! create and implicitly define the label identifier
        Label createAndDefineLabel();

        //! emits a label and marks a patch position if necessary
        void emit(Label label);

        //! emits arbitrary data
        void emit(void const * data, size_t len);

        void emit(IL::Instruction val);
        void emit(double val);
        void emit(std::string val);
        void emit(uint8_t val);
        void emit(uint16_t val);
        void emit(uint32_t val);
    };

    struct CodeReader
    {
        Compiler::CompilationUnit const * code;
        size_t offset;

        void fetch_buffer(void * target, size_t len);

        IL::Instruction fetch_instruction();
        std::string fetch_string();
        double fetch_number();

        uint8_t fetch_u8();
        uint16_t fetch_u16();
        uint32_t fetch_u32();
    };

    struct Scope
    {
        std::vector<std::string> local_variables;
        std::vector<size_t> return_point;

        uint16_t max_locals;

        Scope();
        ~Scope();

        void enter(); //!< pushes a scope to the stack
        void leave(); //!< removes a previously pushed scope and all variables

        void declare(std::string const & name);

        std::optional<uint16_t> get(std::string const & name);
    };

    struct Compiler
    {
        CompilationUnit compile(AST::Program const & program) const;
    };

    struct Disassembler
    {
        void disassemble(CompilationUnit const & cu, std::ostream & stream) const;
    };
}

#endif // COMPILER_HPP
