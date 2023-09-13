import React from "react";
import Modal from "react-modal";

// props.readyState = document.readyState
class UpdateTextModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      currentChar: 0,
      maxChar: 120,
    };
  }

  handleInputChange = (e) => {
    const value = e.target.value;
    const currentChar = value.length;
    this.setState({ currentChar });
  };

  render() {
    const { currentChar, maxChar } = this.state;

    return this.props.readyState !== "loading" && (
      <Modal>
        <textarea
          id="description"
          maxLength={maxChar}
          onChange={this.handleInputChange}
        />
        <div id="descript_amount">{currentChar}/{maxChar}</div>
      </Modal>
    );
  }
}

export default UpdateTextModal;