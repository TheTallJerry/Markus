import React from "react";
import Modal from "react-modal";
import {render} from "react-dom";

// props: this.props.isReady
class CreateTagModal extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      isOpen: false,
      tagName: "",
      tagDescription: "",
      maxCharsTagName: 30,
      maxCharsTagDescription: 120,
      successText: "Tag created successfully",
      success: false,
    };
  }

  fetchData = () => {
    // TODO
  };

  onSubmit = () => {
    // tag_data << {
    //   name: name,
    //   description: description,
    //   role_id: role_id,
    //   assessment_id: assignment_id
    // }
    const data = {
      //   TODO
    };

    $.Ajax({
      method: "post",
      url: Routes.add_tag_api_course_assignment_group_path(
        this.props.course_id,
        this.props.assignment_id,
        this.props.id
      ),
      data: data,
    }).then(response => {
      if (response.ok) {
        this.setState({
          isOpen: false,
          success: true,
        });
      }
    });
  };

  openModal = () => {
    this.setState({isOpen: true});
  };

  closeModal = () => {
    this.setState({isOpen: false});
  };

  handleTagNameChange = event => {
    const newTagName = event.target.value.slice(0, this.state.maxCharsTagName);
    this.setState({tagName: newTagName});
  };

  handleTagDescriptionChange = event => {
    const newTagDescription = event.target.value.slice(0, this.state.maxCharsTagDescription);
    this.setState({tagDescription: newTagDescription});
  };

  render() {
    return (
      this.props.isReady && (
        <div>
          <button onClick={this.openModal}>Open Modal</button>
          <Modal
            isOpen={this.state.isOpen}
            onRequestClose={this.closeModal}
            contentLabel="Example Modal"
          >
            <span className="close" onClick={this.closeModal}>
              &times;
            </span>
            <div>
              <label htmlFor="tagName">Text 1:</label>
              <textarea
                id="tagName"
                value={this.state.tagName}
                onChange={this.handleTagNameChange}
                maxLength={this.state.maxCharsTagName}
                placeholder={"some text"}
              />
              <p>Characters remaining: {this.state.maxCharsTagName - this.state.tagName.length}</p>
            </div>
            <div>
              <label htmlFor="tagDescription">Text 2:</label>
              <textarea
                id="tagDescription"
                value={this.state.tagDescription}
                onChange={this.handleTagDescriptionChange}
                maxLength={this.state.maxCharsTagDescription}
                placeholder={"some text"}
              />
              <p>
                Characters remaining:{" "}
                {this.state.maxCharsTagDescription - this.state.tagDescription.length}
              </p>
            </div>
          </Modal>
        </div>
      )
    );
  }
}

export function makeCreateTagModal(elem, props) {
  return render(<CreateTagModal {...props} />, elem);
}
